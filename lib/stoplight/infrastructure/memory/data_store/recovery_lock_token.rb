# frozen_string_literal: true

module Stoplight
  module Infrastructure
    module Memory
      class DataStore
        class RecoveryLockToken < Domain::RecoveryLockToken
          # @!attribute light_name
          #   @return [String]
          # @dynamic light_name
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
