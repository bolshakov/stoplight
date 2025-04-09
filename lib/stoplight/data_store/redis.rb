# frozen_string_literal: true

module Stoplight
  module DataStore
    # == Errors
    # All errors are stored in the sorted set where keys are serialized errors and
    # values (Redis uses "score" term) contain integer representations of the time
    # when an error happened.
    #
    # This data structure enables us to query errors that happened within a specific
    # period. We use this feature to support +window_size+ option.
    #
    # To avoid uncontrolled memory consumption, we keep at most +config.threshold+ number
    # of errors happened within last +config.window_size+ seconds (by default infinity).
    #
    # @see Base
    class Redis < Base
      KEY_SEPARATOR = ':'
      KEY_PREFIX = %w[stoplight v5].join(KEY_SEPARATOR)

      # @param redis [::Redis]
      def initialize(redis)
        @redis = redis
      end

      def names
        state_names = @redis.hkeys(states_key)

        pattern = key('failures', '*')
        prefix_regex = /^#{key('failures', '')}/
        failure_names = @redis.scan_each(match: pattern).to_a.map do |key|
          key.sub(prefix_regex, '')
        end

        (state_names + failure_names).uniq
      end

      def get_all(config)
        failures, state = @redis.multi do |transaction|
          query_failures(config, transaction: transaction)
          query_state(config, transaction: transaction)
        end

        [
          normalize_failures(failures, config.error_notifier),
          normalize_state(state)
        ]
      end

      def get_failures(config)
        normalize_failures(query_failures(config), config.error_notifier)
      end

      # Saves a new failure to the errors HSet and cleans up outdated errors.
      def record_failure(config, failure)
        *, size = @redis.multi do |transaction|
          failures_key = failures_key(config)

          transaction.zadd(failures_key, failure.time.to_i, failure.to_json)
          remove_outdated_failures(config, failure.time, transaction: transaction)
          transaction.zcard(failures_key)
        end

        size
      end

      def clear_failures(config)
        failures, = @redis.multi do |transaction|
          query_failures(config, transaction: transaction)
          transaction.del(failures_key(config))
        end

        normalize_failures(failures, config.error_notifier)
      end

      def get_state(config)
        state = query_state(config)
        normalize_state(state)
      end

      def set_state(config, state)
        @redis.hset(states_key, config.name, state)
        state
      end

      def clear_state(config)
        state, = @redis.multi do |transaction|
          query_state(config, transaction: transaction)
          transaction.hdel(states_key, config.name)
        end

        normalize_state(state)
      end

      NOTIFICATION_DEDUPLICATION_TTL = 60 # TTL for notification deduplication (in seconds)
      private_constant :NOTIFICATION_DEDUPLICATION_TTL

      # This Lua script implements a notification deduplication mechanism:
      # 1. It checks if the current color transition (from_color → to_color) matches the previously recorded one
      # 2. If it's the same transition, returns 0 (don't notify) to prevent duplicate notifications
      # 3. If it's a different transition (or first time), it:
      #    - Records the new transition with a timestamp
      #    - Sets an expiration time on the record (allowing notifications to repeat after TTL as a fail-safe mechanism)
      #    - Returns 1 (proceed with notification)
      #
      # This ensures that when multiple servers detect the same transition simultaneously,
      # only one notification is sent, while still allowing future transitions to trigger notifications.
      #
      # This script is executed on redis and it's guaranteed that the operations are atomic.
      NOTIFICATION_DEDUPLICATION_SCRIPT = <<~LUA
        local last_notification_key = KEYS[1]

        local light_name = ARGV[1]
        local from_color = ARGV[2]
        local to_color = ARGV[3]
        local ttl = tonumber(ARGV[4])

        local prev_transition = redis.call('HMGET', last_notification_key, 'from_color', 'to_color')
        local prev_from_color, prev_to_color = unpack(prev_transition)

        if prev_from_color == from_color and prev_to_color == to_color then
          return 0
        else
          redis.call('HSET', last_notification_key, 'from_color', from_color, 'to_color', to_color)
          redis.call('EXPIRE', last_notification_key, ttl)
          return 1
        end
      LUA
      private_constant :NOTIFICATION_DEDUPLICATION_SCRIPT

      def with_deduplicated_notification(config, from_color, to_color)
        deduplication_status = @redis.eval(
          NOTIFICATION_DEDUPLICATION_SCRIPT,
          keys: [last_notification_key(config)],
          argv: [config.name, from_color, to_color, NOTIFICATION_DEDUPLICATION_TTL]
        )

        yield if Integer(deduplication_status) == 1
      end

      private

      # @param config [Stoplight::Light::Config]
      # @param time [Time]
      def remove_outdated_failures(config, time, transaction: @redis)
        failures_key = failures_key(config)

        # Remove all errors happened before the window start
        transaction.zremrangebyscore(failures_key, 0, time.to_i - config.window_size)
        # Keep at most +config.threshold+ number of errors
        transaction.zremrangebyrank(failures_key, 0, -config.threshold - 1)
      end

      def query_failures(config, transaction: @redis)
        window_start = Time.now.to_i - config.window_size

        transaction.zrange(failures_key(config), Float::INFINITY, window_start, rev: true, by_score: true)
      end

      def normalize_failures(failures, error_notifier)
        failures.map do |json|
          Failure.from_json(json)
        rescue StandardError => e
          error_notifier.call(e)
          Failure.from_error(e)
        end
      end

      def query_state(config, transaction: @redis)
        transaction.hget(states_key, config.name)
      end

      def normalize_state(state)
        state || State::UNLOCKED
      end

      # We store a list of failures happened in the  +config+ in this key
      #
      # @param config [Stoplight::Light::Config]
      # @return [String]
      def failures_key(config)
        key('failures', config.name)
      end

      def last_notification_key(config)
        key('last_notification', config.name)
      end

      def states_key
        key('states')
      end

      def key(*pieces)
        ([KEY_PREFIX] + pieces).join(KEY_SEPARATOR)
      end
    end
  end
end
