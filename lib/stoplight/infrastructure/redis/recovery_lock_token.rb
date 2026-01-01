# frozen_string_literal: true

require "securerandom"

module Stoplight
  module Infrastructure
    module Redis
      class RecoveryLockToken < Domain::RecoveryLockToken
        # @!attribute token
        #   @return [String]
        attr_reader :token

        def initialize
          @token = SecureRandom.uuid
        end
      end
    end
  end
end
