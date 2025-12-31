# frozen_string_literal: true

require "concurrent/map"

module Stoplight
  module Infrastructure
    module DataStore
      class Memory
        # Process-local recovery lock using Ruby's Thread::Mutex.
        #
        # This only serializes recovery within a single Ruby process.
        # Multiple processes/servers will NOT coordinate - each process
        # can send probes independently.
        #
        # Mutex Lifecycle:
        # - One mutex created per unique light_name (lazily)
        # - Mutexes persist for process lifetime (never GC'd)
        #
        class RecoveryLockStore
          # @!attribute locks
          #   Stores one mutex per unique light_name for the lifetime of the process.
          #   Mutexes are never garbage collected.
          #   @return [Concurrent::Map<Thread::Mutex>]
          # @dynamic locks
          private attr_reader :locks

          def initialize
            @locks = Concurrent::Map.new
          end

          # @param light_name [String]
          # @return [Stoplight::Infrastructure::DataStore::Memory::RecoveryLockToken, nil]
          def acquire_lock(light_name)
            lock = lock_for(light_name)
            RecoveryLockToken.new(light_name:) if lock.try_lock
          end

          # @param recovery_lock_token [Stoplight::Infrastructure::DataStore::Memory::RecoveryLockToken]
          # @return [void]
          def release_lock(recovery_lock_token)
            lock_for(recovery_lock_token.light_name).unlock
          end

          # @param light_name [String]
          # @return [Thread::Mutex]
          private def lock_for(light_name)
            locks.compute_if_absent(light_name) do
              Thread::Mutex.new
            end
          end
        end
      end
    end
  end
end
