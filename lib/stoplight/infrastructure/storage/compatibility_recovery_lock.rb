# frozen_string_literal: true

module Stoplight
  module Infrastructure
    module Storage
      # Temporary adapter that bridges +Domain::Storage::RecoveryLock+ to existing DataStore.
      #
      # This compatibility layer allows the recovery lock abstraction to be
      # introduced without breaking existing data store implementations. It
      # delegates all lock operations to the data store's original methods.
      #
      # This adapter will be removed in a future versions once all
      # data stores have native recovery lock implementations.
      #
      # @see Stoplight::Domain::_RecoveryLockStore
      class CompatibilityRecoveryLock
        def initialize(data_store:, config:)
          @data_store = data_store
          @config = config
        end

        def acquire_lock = data_store.acquire_recovery_lock(config) #: Domain::Storage::RecoveryLockToken?

        def release_lock(lock) = data_store.release_recovery_lock(lock)

        private

        attr_reader :data_store
        attr_reader :config
      end
    end
  end
end
