# frozen_string_literal: true

module Stoplight
  module Infrastructure
    module Redis
      module Storage
        class Registry
          def initialize(redis:, key_space:, clock:, config_serializer:)
            @redis = redis
            @key_space = key_space
            @clock = clock
            @config_serializer = config_serializer
          end

          def ids
            @redis.with do |conn|
              conn.hkeys(key)
            end
          end

          def register(config)
            @redis.with do |conn|
              conn.hset(
                key,
                config.id,
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

          def unregister(id)
            @redis.with do |conn|
              conn.hdel(key, id)
            end
          end

          def all_configs
            raw_lights_info = @redis.with do |conn|
              conn.hgetall(key)
            end
            return [] unless raw_lights_info
            raw_lights_info.filter_map do |_, config|
              next unless config

              begin
                JSON.parse(config)["config"]
              rescue JSON::ParserError
                nil
              end
            end
          end

          def config_for(id)
            raw_light_info = @redis.with do |conn|
              conn.hget(key, id)
            end
            return unless raw_light_info
            light_info = JSON.parse(raw_light_info)
            light_info["config"]
          end

          private def key = @key_space.join("lights")
        end
      end
    end
  end
end
