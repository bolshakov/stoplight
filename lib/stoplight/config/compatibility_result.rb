# frozen_string_literal: true

module Stoplight
  module Config
    # The +CompatibilityResult+ class represents the result of a compatibility check
    # for a strategy. It provides methods to determine if the strategy is compatible
    # and to retrieve error messages when it is not.
    class CompatibilityResult
      class << self
        # Creates a new +CompatibilityResult+ instance representing a compatible strategy.
        #
        # @return [CompatibilityResult] An instance with no errors.
        def compatible
          new(errors: [])
        end

        # Creates a new +CompatibilityResult+ instance representing an incompatible strategy.
        #
        # @param errors [Array<String>] List of error messages indicating incompatibility.
        # @return [CompatibilityResult] An instance with the provided errors.
        def incompatible(*errors)
          new(errors:)
        end
      end

      # Initializes a new `CompatibilityResult` instance.
      # @param errors [Array<String>] List of error messages if the strategy is not compatible.
      def initialize(errors: [])
        @errors = errors.freeze
      end

      # Checks if the strategy is compatible.
      # @return [Boolean] `true` if there are no errors, `false` otherwise.
      def compatible?
        @errors.empty?
      end

      def incompatible? = !compatible?

      # Retrieves the list of error messages.
      # @return [Array<String>] The list of error messages.
      attr_reader :errors

      # Retrieves a concatenated error message string.
      # @return [String, nil] A string containing all error messages joined by "; ",
      #   or `nil` if the strategy is compatible.
      def error_messages
        unless compatible?
          @errors.join("; ")
        end
      end
    end
  end
end
