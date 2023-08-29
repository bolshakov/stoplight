# frozen_string_literal: true

require 'redlock'

module Stoplight
  module DataStore
    # Data Schema
    #
    # This documentation explains the data schema used for managing failures, states, and usage time
    # in the Stoplight version 4 implementation.
    #
    # 1. "stoplight:v4:failures:{light-name}" -- Failures
    #
    # For each light, its failures are stored in a Sorted Set with the following structure:
    #   - Key: Serialized exception
    #   - Score: Integer representation of the time when the error occurred
    #
    # This data structure enables efficient querying of errors within specific time periods,
    # supporting the use of the +window_size+ option.
    #
    # To prevent uncontrolled memory usage, the system retains a maximum of +light.threshold+
    # errors that occurred within the last +light.window_size+ seconds (default: infinity).
    #
    # 2. "stoplight:v4:states" -- States
    #
    # Light states are stored in a Hash with the following attributes:
    #   - Key: Light's name
    #   - Value: Light's state (from the +Stoplight::States+ set)
    #
    # The state value is updated whenever a light is locked or unlocked.
    #
    # 3. "stoplight:v4:last_used_at" -- Last Usage Time
    #
    # The time of a light's last usage is stored in this Sorted Set:
    #   - Key: Light's name
    #   - Score: Integer representation of the last usage time
    #
    # This information helps track when a specific light was last used
    #
    # Note: Replace "{light-name}" with the actual name of the light in the keys.
    #
    # Example:
    #   "stoplight:v4:failures:traffic-light-1"
    #   "stoplight:v4:states"
    #   "stoplight:v4:last_used_at"
    #
    # @see Base
    class Redis < Base
      KEY_SEPARATOR = ':'
      KEY_PREFIX = %w[stoplight v4].join(KEY_SEPARATOR)
      LIGHT_EXPIRATION_TIME = 7 * 24 * 60 * 60

      # @param redis [::Redis]
      def initialize(redis, redlock: Redlock::Client.new([redis]))
        @redis = redis
        @redlock = redlock
      end

      # @overload names()
      #   @return [Array<String>]
      #
      # @overload names()
      #   @param used_after [Time]
      #   @return [Array<String>]
      #
      def names(used_after: Time.now - LIGHT_EXPIRATION_TIME)
        @redis.zrange(last_used_at_key, used_after.to_i, '+inf', by_score: true)
      end

      def get_all(light)
        failures, state = @redis.multi do |transaction|
          query_failures(light, transaction: transaction)
          transaction.hget(states_key, light.name)
        end

        [
          normalize_failures(failures, light.error_notifier),
          normalize_state(state)
        ]
      end

      def get_failures(light)
        normalize_failures(query_failures(light), light.error_notifier)
      end

      # Saves a new failure to the errors HSet and cleans up outdated errors.
      def record_failure(light, failure)
        *, size = @redis.multi do |transaction|
          failures_key = failures_key(light)

          transaction.zadd(failures_key, failure.time.to_i, failure.to_json)
          remove_outdated_failures(light, failure.time, transaction: transaction)
          transaction.zcard(failures_key)
        end

        size
      end

      def clear_failures(light)
        failures, = @redis.multi do |transaction|
          query_failures(light, transaction: transaction)
          transaction.del(failures_key(light))
        end

        normalize_failures(failures, light.error_notifier)
      end

      def get_state(light)
        query_state(light) || State::UNLOCKED
      end

      def set_state(light, state)
        @redis.hset(states_key, light.name, state)
        state
      end

      def clear_state(light)
        state, = @redis.multi do |transaction|
          query_state(light, transaction: transaction)
          transaction.hdel(states_key, light.name)
        end

        normalize_state(state)
      end

      LOCK_TTL = 2_000 # milliseconds

      def with_notification_lock(light, from_color, to_color)
        @redlock.lock(notification_lock_key(light), LOCK_TTL) do
          if last_notification(light) != [from_color, to_color]
            set_last_notification(light, from_color, to_color)

            yield
          end
        end
      end

      # The last usage time of the light
      # @param light [Stoplight::Light]
      # @param time [Time]
      # @return [void]
      def set_last_used_at(light, time)
        @redis.zadd(last_used_at_key, time.to_i, light.name)
      end

      private

      # @param light [Stoplight::Light]
      # @param time [Time]
      def remove_outdated_failures(light, time, transaction: @redis)
        failures_key = failures_key(light)

        # Remove all errors happened before the window start
        transaction.zremrangebyscore(failures_key, 0, time.to_i - light.window_size)
        # Keep at most +light.threshold+ number of errors
        transaction.zremrangebyrank(failures_key, 0, -light.threshold - 1)
      end

      # @param light [Stoplight::Light]
      # @return [Array, nil]
      def last_notification(light)
        @redis.get(last_notification_key(light))&.split('->')
      end

      # @param light [Stoplight::Light]
      # @param from_color [String]
      # @param to_color [String]
      # @return [void]
      def set_last_notification(light, from_color, to_color)
        @redis.set(last_notification_key(light), [from_color, to_color].join('->'))
      end

      def query_failures(light, transaction: @redis)
        window_start = Time.now.to_i - light.window_size

        transaction.zrange(failures_key(light), Float::INFINITY, window_start, rev: true, by_score: true)
      end

      def normalize_failures(failures, error_notifier)
        failures.map do |json|
          Failure.from_json(json)
        rescue StandardError => e
          error_notifier.call(e)
          Failure.from_error(e)
        end
      end

      def query_state(light, transaction: @redis)
        transaction.hget(states_key, light.name)
      end

      def normalize_state(state)
        state || State::UNLOCKED
      end

      # We store a list of failures happened in the  +light+ in this key
      #
      # @param light [Stoplight::Light]
      # @return [String]
      def failures_key(light)
        key('failures', light.name)
      end

      # We store a time when the +light+ was used the last time in this key
      #
      # @return [String]
      def last_used_at_key
        key('last_used_at')
      end

      def notification_lock_key(light)
        key('notification_lock', light.name)
      end

      def last_notification_key(light)
        key('last_notification', light.name)
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
