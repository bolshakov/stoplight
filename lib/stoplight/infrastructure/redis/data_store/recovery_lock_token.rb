# frozen_string_literal: true

require "securerandom"

module Stoplight
  module Infrastructure
    module Redis
      class DataStore
        class RecoveryLockToken
          attr_reader :light_name
          attr_reader :token

          # @param light_name [String]
          def initialize(light_name:)
            @light_name = light_name
            @token = SecureRandom.uuid
          end

          def lock_key = key(:locks, :recovery, light_name)

          private def key(*parts)
            Stoplight::Infrastructure::Redis::DataStore.key(*parts)
          end
        end
      end
    end
  end
end
