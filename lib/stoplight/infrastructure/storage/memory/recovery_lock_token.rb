# frozen_string_literal: true

require "securerandom"

module Stoplight
  module Infrastructure
    module Storage
      module Memory
        class RecoveryLockToken < Domain::RecoveryLockToken
        end
      end
    end
  end
end
