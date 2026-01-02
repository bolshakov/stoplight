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
      # @see Stoplight::Domain::Storage::RecoveryLock
      class CompatibilityRecoveryLock < Domain::Storage::RecoveryLock
        # @dynamic data_store
        private attr_reader :data_store
        # @dynamic config
        private attr_reader :config

        # @param data_store [Stoplight::Domain::DataStore]
        # @param config [Stoplight::Domain::Config]
        def initialize(data_store:, config:)
          @data_store = data_store
          @config = config
        end

        # @return [Stoplight::Domain::RecoveryLockToken, nil]
        def acquire_lock = data_store.acquire_recovery_lock(config) #: Domain::Storage::RecoveryLockToken?

        # @param lock [Stoplight::Domain::LockToken]
        # @return [void]
        def release_lock(lock) = data_store.release_recovery_lock(lock)
      end
    end
  end
end
