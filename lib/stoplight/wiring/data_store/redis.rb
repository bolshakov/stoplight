# frozen_string_literal: true

module Stoplight
  module Wiring
    module DataStore
      class Redis < Base
        # @!attribute redis
        #   @return [::Redis, ConnectionPool<::Redis>]
        attr_reader :redis

        # @!attribute warn_on_clock_skew
        #   @return [Boolean]
        attr_reader :warn_on_clock_skew

        # @param redis [::Redis, ConnectionPool<::Redis>]
        # @param warn_on_clock_skew [Boolean] (true) Whether to warn about clock skew between Redis and
        #   the application server
        def initialize(redis, warn_on_clock_skew: true)
          @warn_on_clock_skew = warn_on_clock_skew
          @redis = redis
        end

        # @param container [Stoplight::Infrastructure::DependencyInjection::Container]
        # @return [Stoplight::Infrastructure::DataStore::Redis]
        # @api private
        def create(container)
          Stoplight::Infrastructure::DataStore::Redis.new(
            redis: redis,
            warn_on_clock_skew: warn_on_clock_skew,
            recovery_lock_store: container.resolve(:"data_store.redis.recovery_lock_store")
          )
        end
      end
    end
  end
end
