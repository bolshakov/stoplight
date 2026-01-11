module Stoplight
  module Common
    # Represents the presence of a value in an Option type.
    #
    # Used to distinguish between "explicitly configured" (Some) and
    # "not configured" (None) in the Settings DSL, enabling three-state
    # logic: configured, not-configured, and explicitly-nil.
    #
    # @see None
    class Some
      protected attr_reader :value

      def initialize(value)
        @value = value
      end

      def value!
        @value
      end

      def get_or_else
        @value
      end

      def map
        Some.new(yield value)
      end

      def ==(other)
        other.is_a?(Some) && value == other.value # steep:ignore
      end

      def to_s
        "Some(#{@value})"
      end

      def empty? = false
    end
  end
end
