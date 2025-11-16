# frozen_string_literal: true

module Stoplight
  module Infrastructure
    module DataStore
      class Redis
        class RecoveryLockStoreFactory
          private attr_reader :lock_timeout

          # @param lock_timeout [Integer] lock TTL in milliseconds
          def initialize(lock_timeout:)
            @lock_timeout = lock_timeout
          end

          # @param redis [RedisClient | ConnectionPool]
          # @return [Stoplight::Infrastructure::DataStore::Redis::RecoveryLockStore]
          def resolve(redis:)
            RecoveryLockStore.new(redis:, lock_timeout:)
          end
        end
      end
    end
  end
end
