# frozen_string_literal: true

module Stoplight
  module Wiring
    module DataStore
      class Memory < Base
        # @return [Stoplight::Infrastructure::DataStore::Memory]
        # @api private
        def create(container)
          Infrastructure::DataStore::Memory.new(
            recovery_lock_store: container.resolve(:"data_store.memory.recovery_lock_store")
          )
        end
      end
    end
  end
end
