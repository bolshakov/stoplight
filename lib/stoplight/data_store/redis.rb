# coding: utf-8

begin
  require 'redis'
  REDIS_LOADED = true
rescue LoadError
  REDIS_LOADED = false
end

module Stoplight
  module DataStore
    class Redis < Base
      def initialize(*args)
        fail Error::NoRedis unless REDIS_LOADED

        @redis = ::Redis.new(*args)
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
    end
  end
end
