# frozen_string_literal: true

module Stoplight
  module Infrastructure
    module Redis
      module Storage
        class Registry
          REDIS_KEY = "lights"
          private_constant :REDIS_KEY

          def initialize(redis:, key_space:, clock:, config_serializer:)
            @redis = redis
            @key_space = key_space
            @clock = clock
            @config_serializer = config_serializer
          end

          def names
            @redis.with do |conn|
              conn.hkeys(key)
            end
          end

          def register(name, config:)
            @redis.with do |conn|
              conn.hset(
                key,
                name,
                {
                  meta: {
                    version: 1,
                    registered_at: @clock.current_time.to_i
                  },
                  config: @config_serializer.call(config)
                }.to_json
              )
            end
          end

          def unregister(name)
            @redis.with do |conn|
              conn.hdel(key, name)
            end
          end

          def config_for(name)
            raw_light_info = @redis.with do |conn|
              conn.hget(key, name)
            end
            return unless raw_light_info
            light_info = JSON.parse(raw_light_info)
            light_info["config"]
          end

          private def key
            @key_space.key(REDIS_KEY)
          end
        end
      end
    end
  end
end
