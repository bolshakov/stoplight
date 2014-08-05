# coding: utf-8

begin
  require 'redis'
  REDIS_LOADED = true
rescue LoadError
  REDIS_LOADED = false
end

module Stoplight
  module DataStore
    # @note redis ~> 3.1.0
    class Redis < Base
      def initialize(*args)
        fail Error::NoRedis unless REDIS_LOADED

        @redis = ::Redis.new(*args)
      end

      def names
        @redis.scan_each(match: "#{KEY_PREFIX}:*:*").map do |key|
          match = /^#{KEY_PREFIX}:(.+):[^:]+$/.match(key)
          match[1] if match
        end.uniq
      end

      def record_failure(name, error)
        failure = Failure.new(error)
        @redis.rpush(failure_key(name), failure.to_json)
        # TODO: Trim failures (think ring buffer). Probably in a multi block.
      end

      def clear_failures(name)
        @redis.del(failure_key(name))
      end

      def failures(name)
        @redis.lrange(failure_key(name), 0, -1)
      end

      def failure_threshold(name)
        value = @redis.hget(settings_key(name), 'failure_threshold')
        Integer(value) if value # REVIEW: Fault tolerance.
      end

      def set_failure_threshold(name, threshold)
        # REVIEW: Make sure threshold is an integer.
        @redis.hset(settings_key(name), 'failure_threshold', threshold)
        threshold
      end

      def record_attempt(name)
        @redis.incr(attempt_key(name))
      end

      def state(name)
        @redis.hget(settings_key(name), 'state') || STATE_UNLOCKED
      end

      def set_state(name, state)
        validate_state!(state)
        @redis.hset(settings_key(name), 'state', state)
        state
      end
    end
  end
end
