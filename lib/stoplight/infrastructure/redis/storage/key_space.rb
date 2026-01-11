# frozen_string_literal: true

require "digest"

module Stoplight
  module Infrastructure
    module Redis
      module Storage
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
        KeySpace = Data.define(:system_id, :light_id)

        class KeySpace
          # @!attribute system_id
          #   12-char hex identifier for the system
          #
          # @!attribute light_id
          #   12-char hex identifier for the light

          class << self
            def build(system_name:, light_name:) = new(
              system_id: hash_name(system_name),
              light_id: hash_name(light_name)
            )

            # Generates a truncated SHA256 hash for use in Redis keys.
            def hash_name(name) = Digest::SHA256.hexdigest(name.to_s)[0, 12] #: String
          end

          # Builds a Redis key within this namespace.
          #
          # @param pieces  Key segments to append
          # @return  Full Redis key
          def key(*pieces) = [:stoplight, :v6, system_id, "{#{light_id}}", *pieces].join(":")
        end
      end
    end
  end
end
