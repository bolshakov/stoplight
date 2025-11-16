# frozen_string_literal: true

module Stoplight
  module Infrastructure
    module DataStore
      class Redis
        class RecoveryLockFactory
          # @param lock_timeout [Integer] lock TTL in milliseconds
          def initialize(lock_timeout:)
            @lock_timeout = lock_timeout
          end

          # @param redis [RedisClient | ConnectionPool]
          # @param data_store [Stoplight::Infrastructure::DataStore::Redis]
          # @return [Stoplight::Infrastructure::DataStore::Redis::RecoveryLock]
          def resolve(redis:, data_store:)
            RecoveryLock.new(redis:, data_store:, lock_timeout: @lock_timeout)
          end
        end
      end
    end
  end
end
