# frozen_string_literal: true

module Stoplight
  module Infrastructure
    module Storage
      module Memory
        # Process-local recovery lock using Ruby's Thread::Mutex.
        #
        # This only serializes recovery within a single Ruby process.
        # Multiple processes/servers will NOT coordinate - each process
        # can send probes independently.
        #
        class RecoveryLock < Domain::Storage::RecoveryLock
          # @!attribute lock
          #   @return [Thread::Mutex]
          private attr_reader :lock

          def initialize
            @lock = Thread::Mutex.new
          end

          # @return [Stoplight::Domain::RecoveryLockToken, nil]
          def acquire_lock
            if lock.try_lock
              Domain::RecoveryLockToken.new
            end
          end

          # @param _recovery_lock_token [Stoplight::Domain::RecoveryLockToken]
          # @return [void]
          def release_lock(_recovery_lock_token)
            lock.unlock
          end
        end
      end
    end
  end
end
