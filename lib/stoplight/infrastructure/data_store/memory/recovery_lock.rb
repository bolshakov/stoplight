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
        class RecoveryLock < Domain::RecoveryLock
          # @!attribute data_store
          #   @return [Stoplight::Infrastructure::DataStore::Memory]
          private attr_reader :data_store

          # @!attribute locks
          #   Stores one mutex per unique light_name for the lifetime of the process.
          #   Mutexes are never garbage collected.
          #   @return [Concurrent::Map<Thread::Mutex>]
          private attr_reader :locks

          def initialize(data_store:)
            @data_store = data_store
            @locks = Concurrent::Map.new
          end

          def with_lock(light_name)
            lock = lock_for(light_name)
            if acquire_lock(lock)
              begin
                yield data_store
              ensure
                release_lock(lock)
              end
              true
            else
              false
            end
          end

          # @param lock [Thread::Mutex]
          # @return [Boolean]
          private def acquire_lock(lock)
            lock.try_lock
          end

          # @param lock [Thread::Mutex]
          # @return [void]
          private def release_lock(lock)
            lock.unlock
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
