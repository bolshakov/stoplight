# coding: utf-8

module Stoplight
  module DataStore
    # @see Base
    class RedisWithoutThreshold < Redis
      # @param light [Stoplight::Light]
      # @param failure [Stoplight::Failure]
      def record_failure(light, failure)
        size, = @redis.multi do
          @redis.lpush(failures_key(light), failure.to_json)
          @redis.ltrim(failures_key(light), 0, light.threshold - 1)
        end

        size
      end

      def query_failures(light)
        @redis.lrange(failures_key(light), 0, -1)
      end
    end
  end
end
