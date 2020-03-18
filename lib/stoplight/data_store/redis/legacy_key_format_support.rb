module Stoplight
  module DataStore
    class Redis
      module LegacyKeyFormatSupport
        # @param light [Stoplight::Light]
        # @return [Boolean]
        def legacy_key_format?(light)
          failures_key = failures_key(light)
          @redis.type(failures_key) == 'list'
        end

        # @param light [Stoplight::Light]
        # @param failure [Stoplight::Failure]
        def record_failure(light, failure)
          return super unless legacy_key_format?(light)

          size, = @redis.multi do
            @redis.lpush(failures_key(light), failure.to_json)
            @redis.ltrim(failures_key(light), 0, light.threshold - 1)
          end

          size
        end

        def query_failures(light)
          return super unless legacy_key_format?(light)

          @redis.lrange(failures_key(light), 0, -1)
        end
      end
    end
  end
end
