# frozen_string_literal: true

module Stoplight
  module Infrastructure
    module DataStore
      class Memory
        class RecoveryLockStoreFactory
          # @return [Stoplight::Infrastructure::DataStore::Memory::RecoveryLockStore]
          def resolve = RecoveryLockStore.new
        end
      end
    end
  end
end
