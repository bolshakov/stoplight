# frozen_string_literal: true

module Stoplight
  module Domain
    # The +CompatibilityResult+ class represents the result of a compatibility check
    # for a strategy. It provides methods to determine if the strategy is compatible
    # and to retrieve error messages when it is not.
    class CompatibilityResult
      class << self
        # Creates a new +CompatibilityResult+ instance representing a compatible strategy.
        #
        # @return An instance with no errors.
        def compatible
          new(errors: [])
        end

        # Creates a new +CompatibilityResult+ instance representing an incompatible strategy.
        #
        # @param errors List of error messages indicating incompatibility.
        # @return An instance with the provided errors.
        def incompatible(*errors)
          new(errors:)
        end
      end

      # Initializes a new `CompatibilityResult` instance.
      # @param errors List of error messages if the strategy is not compatible.
      def initialize(errors: [])
        @errors = errors.freeze
      end

      # Checks if the strategy is compatible.
      # @return `true` if there are no errors, `false` otherwise.
      def compatible?
        @errors.empty?
      end

      def incompatible? = !compatible?

      # Retrieves the list of error messages.
      # @return  The list of error messages.
      attr_reader :errors

      # Retrieves a concatenated error message string.
      # @return A string containing all error messages joined by "; ",
      #   or `nil` if the strategy is compatible.
      def error_messages
        unless compatible?
          @errors.join("; ")
        end
      end
    end
  end
end
