# frozen_string_literal: true

module Stoplight
  module Infrastructure
    module DataStore
      class Memory
        class RecoveryLockFactory
          # @param data_store [Stoplight::Infrastructure::DataStore::Memory]
          # @return [Stoplight::Infrastructure::DataStore::Memory::RecoveryLock]
          def resolve(data_store:)
            RecoveryLock.new(data_store:)
          end
        end
      end
    end
  end
end
