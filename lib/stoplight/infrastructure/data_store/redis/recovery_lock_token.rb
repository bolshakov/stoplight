# frozen_string_literal: true

require "securerandom"
require "forwardable"

module Stoplight
  module Infrastructure
    module DataStore
      class Redis
        class RecoveryLockToken < Domain::RecoveryLockToken
          extend Forwardable

          def_delegator "Stoplight::Infrastructure::DataStore::Redis", :key
          private :key

          # @!attribute light_name
          #   @return [String]
          attr_reader :light_name

          # @!attribute token
          #   @return [String]
          attr_reader :token

          # @param light_name [String]
          def initialize(light_name:)
            @light_name = light_name
            @token = SecureRandom.uuid
          end

          def lock_key = key(:recovery_lock, light_name)
        end
      end
    end
  end
end
