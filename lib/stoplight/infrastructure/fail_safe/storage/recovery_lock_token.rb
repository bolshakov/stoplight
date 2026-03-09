# frozen_string_literal: true

module Stoplight
  module Infrastructure
    module FailSafe
      module Storage
        class RecoveryLockToken
          attr_reader :underlying_token
          attr_reader :origin

          def initialize(underlying_token:, origin:)
            @underlying_token = underlying_token
            @origin = origin
          end
        end
      end
    end
  end
end
