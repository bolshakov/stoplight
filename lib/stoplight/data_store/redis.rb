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
      KEY_SEPARATOR = ":"
      KEY_PREFIX = %w[stoplight v5].join(KEY_SEPARATOR)
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

      RECORD_FAILURE_SCRIPT = <<~LUA
        local failures_key = KEYS[1]
        local current_time = tonumber(ARGV[1])
        local window_size = tonumber(ARGV[2])
        local threshold = tonumber(ARGV[3])
        local failure_json = ARGV[4]
        
        -- Add new failure
        redis.call('ZADD', failures_key, current_time, failure_json)
        
        -- Calculate window boundaries
        local window_start = current_time - window_size
        
        -- Remove failures outside time window
        redis.call('ZREMRANGEBYSCORE', failures_key, 0, window_start)
          
        -- Keep at most threshold failures (remove oldest)
        redis.call('ZREMRANGEBYRANK', failures_key, 0, -threshold - 1)
        
        -- Count only failures within current window
        return redis.call('ZCOUNT', failures_key, window_start, '+inf')
      LUA
      private_constant :RECORD_FAILURE_SCRIPT

      # @param redis [::Redis, ConnectionPool<::Redis>]
      def initialize(redis)
        @redis = redis
        @notification_deduplication_script_sha = @redis.then do |client|
          client.script("load", NOTIFICATION_DEDUPLICATION_SCRIPT)
        end
        @record_failure_script_sha = @redis.then do |client|
          client.script("load", RECORD_FAILURE_SCRIPT)
        end
      end

      def names
        state_names = @redis.then { _1.hkeys(states_key) }

        pattern = key("failures", "*")
        prefix_regex = /^#{key("failures", "")}/
        failure_names = @redis.then do |client|
          client.scan_each(match: pattern).to_a.map do |key|
            key.sub(prefix_regex, "")
          end
        end

        (state_names + failure_names).uniq
      end

      def get_all(config)
        failures, state = @redis.then do |client|
          client.pipelined do |pipeline|
            query_failures(config, transaction: pipeline)
            query_state(config, transaction: pipeline)
          end
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
        failures_key = failures_key(config)
        current_time = failure.time.to_i

        @redis.then do |client|
          client.evalsha(
            @record_failure_script_sha,
            keys: [failures_key],
            argv: [current_time, config.window_size, config.threshold, failure.to_json]
          )
        end
      end

      def clear_failures(config)
        failures, = @redis.then do |client|
          client.multi do |transaction|
            query_failures(config, transaction: transaction)
            transaction.del(failures_key(config))
          end
        end

        normalize_failures(failures, config.error_notifier)
      end

      def get_state(config)
        state = query_state(config)
        normalize_state(state)
      end

      def set_state(config, state)
        @redis.then { _1.hset(states_key, config.name, state) }
        state
      end

      def clear_state(config)
        state, = @redis.then do |client|
          client.multi do |transaction|
            query_state(config, transaction: transaction)
            transaction.hdel(states_key, config.name)
          end
        end

        normalize_state(state)
      end

      NOTIFICATION_DEDUPLICATION_TTL = 60 # TTL for notification deduplication (in seconds)
      private_constant :NOTIFICATION_DEDUPLICATION_TTL

      def with_deduplicated_notification(config, from_color, to_color)
        deduplication_status = @redis.then do |client|
          client.evalsha(
            @notification_deduplication_script_sha,
            keys: [last_notification_key(config)],
            argv: [config.name, from_color, to_color, NOTIFICATION_DEDUPLICATION_TTL]
          )
        end

        yield if Integer(deduplication_status) == 1
      end

      private

      def query_failures(config, transaction: @redis)
        window_start = Time.now.to_i - config.window_size

        transaction.then do |client|
          client.zrange(failures_key(config), Float::INFINITY, window_start, rev: true, by_score: true)
        end
      end

      def normalize_failures(failures, error_notifier)
        failures.map do |json|
          Failure.from_json(json)
        rescue => e
          error_notifier.call(e)
          Failure.from_error(e)
        end
      end

      def query_state(config, transaction: @redis)
        transaction.then do |client|
          client.hget(states_key, config.name)
        end
      end

      def normalize_state(state)
        state || State::UNLOCKED
      end

      # We store a list of failures happened in the  +config+ in this key
      #
      # @param config [Stoplight::Light::Config]
      # @return [String]
      def failures_key(config)
        key("failures", config.name)
      end

      def last_notification_key(config)
        key("last_notification", config.name)
      end

      def states_key
        key("states")
      end

      def key(*pieces)
        ([KEY_PREFIX] + pieces).join(KEY_SEPARATOR)
      end
    end
  end
end
