module Stoplight
  # Shared utilities and data structures.
  module Common
    # Wraps a value in a Some, indicating presence.
    def self.some(value)
      Some.new(value) # steep:ignore
    end

    # Returns a None instance, indicating absence.W
    def self.none
      None.new
    end
  end
end
