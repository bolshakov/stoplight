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
        @redis.hkeys("#{KEY_PREFIX}:states")
      end

      # @group Attempts

      def attempts(name)
        @redis.hget("#{KEY_PREFIX}:attempts", name).to_i
      end

      def record_attempt(name)
        @redis.hincrby("#{KEY_PREFIX}:attempts", name, 1)
      end

      def clear_attempts(name)
        @redis.hdel("#{KEY_PREFIX}:attempts", name)
      end

      # @group Failures

      def failures(name)
        @redis.lrange(failure_key(name), 0, -1)
      end

      def record_failure(name, error)
        @redis.rpush(failure_key(name), Failure.new(error).to_json)
      end

      def clear_failures(name)
        @redis.del(failure_key(name))
      end

      # @group State

      def state(name)
        @redis.hget("#{KEY_PREFIX}:states", name) || STATE_UNLOCKED
      end

      def set_state(name, state)
        validate_state!(state)
        @redis.hset("#{KEY_PREFIX}:states", name, state)
        state
      end

      # @group Threshold

      def threshold(name)
        value = @redis.hget("#{KEY_PREFIX}:thresholds", name)
        Integer(value) if value
      end

      def set_threshold(name, threshold)
        @redis.hset("#{KEY_PREFIX}:thresholds", name, threshold)
        threshold
      end
    end
  end
end
