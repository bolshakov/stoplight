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
        @redis.scan_each(match: "#{DataStore::KEY_PREFIX}:*:*").map do |key|
          key[/^#{DataStore::KEY_PREFIX}:(.+):[^:]+$/o, 1]
        end.uniq
      end

      def purge
        names
          .select { |l| failures(l).empty? }
          .each   { |l| delete(l) }
      end

      def delete(name)
        keys = [attempt_key(name), failure_key(name), settings_key(name)]
        keys.each { |k| @redis.del(k) }
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

      def threshold(name)
        value = @redis.hget(settings_key(name), 'threshold')
        Integer(value) if value
      end

      def set_threshold(name, threshold)
        @redis.hset(settings_key(name), 'threshold', threshold)
        threshold
      end

      def record_attempt(name)
        @redis.incr(attempt_key(name))
      end

      def clear_attempts(name)
        @redis.del(attempt_key(name))
      end

      def attempts(name)
        @redis.get(attempt_key(name)).to_i
      end

      def state(name)
        @redis.hget(settings_key(name), 'state') || DataStore::STATE_UNLOCKED
      end

      def set_state(name, state)
        validate_state!(state)
        @redis.hset(settings_key(name), 'state', state)
        state
      end
    end
  end
end
