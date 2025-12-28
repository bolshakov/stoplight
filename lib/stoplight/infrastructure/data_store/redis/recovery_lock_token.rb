# frozen_string_literal: true

require "securerandom"

module Stoplight
  module Infrastructure
    module DataStore
      class Redis
        class RecoveryLockToken < Domain::RecoveryLockToken
          private def key(*parts)
            Stoplight::Infrastructure::DataStore::Redis.key(*parts)
          end

          # @!attribute light_name
          #   @return [String]
          # @dynamic light_name
          attr_reader :light_name

          # @!attribute token
          #   @return [String]
          # @dynamic token
          attr_reader :token

          # @param light_name [String]
          def initialize(light_name:)
            @light_name = light_name
            @token = SecureRandom.uuid
          end

          def lock_key = key(:locks, :recovery, light_name)
        end
      end
    end
  end
end
