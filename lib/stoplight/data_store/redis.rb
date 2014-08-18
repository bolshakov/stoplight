# coding: utf-8

require 'json'
require 'time'

module Stoplight
  module DataStore
    class Redis < Base
      def initialize(redis)
        @redis = redis
      end

      def names
        @redis.hkeys(thresholds_key)
      end

      def purge
        names
          .select { |l| failures(l).empty? }
          .each   { |l| delete(l) }
      end

      def delete(name)
        @redis.pipelined do
          clear_attempts(name)
          clear_failures(name)
          @redis.hdel(states_key, name)
          @redis.hdel(thresholds_key, name)
        end
      end

      def color(name)
        failures = state = threshold = timeout = nil
        @redis.multi do
          failures = @redis.lrange(failures_key(name), 0, -1)
          state = @redis.hget(states_key, name)
          threshold = @redis.hget(thresholds_key, name)
          timeout = @redis.hget(timeouts_key, name)
        end

        case state.value
        when STATE_LOCKED_GREEN
          COLOR_GREEN
        when STATE_LOCKED_RED
          COLOR_RED
        else
          failures = failures.value
          threshold = threshold.value ? threshold.value.to_i : Stoplight::DEFAULT_THRESHOLD
          return COLOR_GREEN if failures.size < threshold
          return COLOR_RED if failures.empty?

          time = Time.parse(JSON.parse(failures.last)['time'])
          timeout = timeout.value ? timeout.value.to_i : Stoplight::DEFAULT_TIMEOUT
          return COLOR_YELLOW if Time.now - time > timeout

          COLOR_RED
        end
      end

      # @group Attempts

      def attempts(name)
        @redis.hget(attempts_key, name).to_i
      end

      def record_attempt(name)
        @redis.hincrby(attempts_key, name, 1)
      end

      def clear_attempts(name)
        @redis.hdel(attempts_key, name)
      end

      # @group Failures

      def failures(name)
        @redis.lrange(failures_key(name), 0, -1)
      end

      def record_failure(name, error)
        @redis.rpush(failures_key(name), Failure.new(error).to_json)
      end

      def clear_failures(name)
        @redis.del(failures_key(name))
      end

      # @group State

      def state(name)
        @redis.hget(states_key, name) || STATE_UNLOCKED
      end

      def set_state(name, state)
        validate_state!(state)
        @redis.hset(states_key, name, state)
        state
      end

      # @group Threshold

      def threshold(name)
        value = @redis.hget(thresholds_key, name)
        Integer(value) if value
      end

      def set_threshold(name, threshold)
        @redis.hset(thresholds_key, name, threshold)
        threshold
      end

      # @group Timeout

      def timeout(name)
        timeout = @redis.hget(timeouts_key, name)
        timeout.to_i if timeout
      end

      def set_timeout(name, timeout)
        @redis.hset(timeouts_key, name, timeout)
        timeout
      end
    end
  end
end
