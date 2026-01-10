# frozen_string_literal: true

module Stoplight
  module Infrastructure
    module Memory
      module Storage
        # Process-local recovery lock using Ruby's Thread::Mutex.
        #
        # This only serializes recovery within a single Ruby process.
        # Multiple processes/servers will NOT coordinate - each process
        # can send probes independently.
        #
        class RecoveryLock
          def initialize
            @lock = Thread::Mutex.new
          end

          def acquire_lock
            if lock.try_lock
              Domain::Storage::RecoveryLockToken.new
            end
          end

          def release_lock(_recovery_lock_token)
            lock.unlock
          end

          private

          attr_reader :lock
        end
      end
    end
  end
end
