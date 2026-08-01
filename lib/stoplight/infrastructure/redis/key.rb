# frozen_string_literal: true

module Stoplight
  module Infrastructure
    module Redis
      # Immutable key namespace for a light within a system.
      #
      # @example
      #   key_space #=> "stoplight:v6:df384ae97c77:{cfe6861fa39e}"
      #   key_space.join(:locks, :recovery)  #=> "stoplight:v6:df384ae97c77:{cfe6861fa39e}:locks:recovery"
      class Key < String
        def initialize(*segments)
          super(segments.join(":"))
          freeze
        end

        # Builds a Redis key.
        #
        # @param segments to append
        # @return Full Redis key
        def join(*segments) = Key.new(self, *segments)
      end
    end
  end
end
