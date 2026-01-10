# frozen_string_literal: true

module Stoplight
  module Domain
    module Storage
      class RecoveryLockToken
        attr_reader :token

        def initialize
          @token = SecureRandom.uuid
        end
      end
    end
  end
end
