# frozen_string_literal: true

module Stoplight
  module Infrastructure
    module Redis
      module Storage
        SystemKeySpace = Data.define(:system_id)

        class SystemKeySpace
          class << self
            def build(system_name:) = new(
              system_id: hash_name(system_name)
            )

            # Generates a truncated SHA256 hash for use in Redis keys.
            def hash_name(name) = Digest::SHA256.hexdigest(name.to_s)[0, 12] #: String
          end

          # Builds a Redis key within this namespace.
          #
          # @param pieces  Key segments to append
          # @return  Full Redis key
          def key(*pieces) = [:stoplight, :v5, system_id, *pieces].join(":")
        end
      end
    end
  end
end
