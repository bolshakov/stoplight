module Stoplight
  module Common
    # Represents the absence of a value in an Option type.
    #
    # When a setting is None, it means the user hasn't configured it,
    # allowing downstream code to apply library defaults.
    #
    # @see Some
    class None
      def value!
        raise RuntimeError, "None does not hold a value", caller(1)
      end

      def get_or_else
        yield
      end

      def map
        self
      end

      def ==(other)
        other.is_a?(None)
      end

      def to_s
        "None"
      end

      def empty? = true
    end
  end
end
