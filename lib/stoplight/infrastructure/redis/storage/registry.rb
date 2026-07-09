# frozen_string_literal: true

module Stoplight
  module Infrastructure
    module Redis
      module Storage
        class Registry
          REDIS_KEY = "lights"
          private_constant :REDIS_KEY

          def initialize(redis:, key_space:, clock:)
            @redis = redis
            @key_space = key_space
            @clock = clock
          end

          def names
            @redis.with do |conn|
              conn.hkeys(@key_space.key(REDIS_KEY))
            end
          end

          def register(name, config:)
            @redis.with do |conn|
              conn.hset(
                @key_space.key(REDIS_KEY),
                name,
                {
                  meta: {
                    version: 1,
                    registered_at: @clock.current_time.to_i
                  }
                }.to_json
              )
            end
          end

          def unregister(name)
            @redis.with do |conn|
              conn.hdel(@key_space.key(REDIS_KEY), name)
            end
          end
        end
      end
    end
  end
end
