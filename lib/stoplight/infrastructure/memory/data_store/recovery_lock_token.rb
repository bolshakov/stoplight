# frozen_string_literal: true

module Stoplight
  module Infrastructure
    module Memory
      class DataStore
        class RecoveryLockToken
          attr_reader :light_name

          def initialize(light_name:)
            @light_name = light_name
          end
        end
      end
    end
  end
end
