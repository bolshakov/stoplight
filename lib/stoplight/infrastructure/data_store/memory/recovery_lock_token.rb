# frozen_string_literal: true

module Stoplight
  module Infrastructure
    module DataStore
      class Memory
        class RecoveryLockToken < Domain::RecoveryLockToken
          # @!attribute light_name
          #   @return [String]
          attr_reader :light_name

          # @param light_name [String]
          def initialize(light_name:)
            @light_name = light_name
          end
        end
      end
    end
  end
end
