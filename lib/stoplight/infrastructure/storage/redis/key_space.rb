# frozen_string_literal: true

require "digest"

module Stoplight
  module Infrastructure
    module Storage
      module Redis
        # Immutable key namespace for a light within a system.
        #
        # Produces keys following entity-first structure:
        #   stoplight:v6:{system_id}:{light_id}:locks:recovery
        #   stoplight:v6:{system_id}:{light_id}:metrics:successes
        #   stoplight:v6:{system_id}:{light_id}:state
        #
        # Identifiers are derived from SHA-256 and truncated to 12 characters. Collisions are extremely
        # unlikely at expected system scale.
        #
        # @example
        #   key_space = KeySpace.build(system_name: "payments", light_name: "stripe-api")
        #   key_space.key(:locks, :recovery)  #=> "stoplight:v6:df384ae97c77:cfe6861fa39e:locks:recovery"
        #
        # @!attribute system_id
        #   @return [String] 12-char hex identifier for the system
        #
        # @!attribute light_id
        #   @return [String] 12-char hex identifier for the light
        #
        KeySpace = Data.define(:system_id, :light_id) do
          class << self
            # @param system_name [String, Symbol]
            # @param light_name [String, Symbol]
            # @return [Stoplight::Infrastructure::Storage::Redis::KeySpace]
            def build(system_name:, light_name:) = new(
              system_id: hash_name(system_name),
              light_id: hash_name(light_name)
            )

            # Generates a truncated SHA256 hash for use in Redis keys.
            #
            # @param name [String, Symbol]
            # @return [String] 12-char hex string
            def hash_name(name) = Digest::SHA256.hexdigest(name.to_s)[0, 12]
          end

          # Builds a Redis key within this namespace.
          #
          # @param pieces [Array<String, Symbol>] Key segments to append
          # @return [String] Full Redis key
          def key(*pieces) = [:stoplight, :v6, system_id, light_id, *pieces].join(":")
        end
      end
    end
  end
end
