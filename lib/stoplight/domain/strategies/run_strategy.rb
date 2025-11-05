# frozen_string_literal: true

module Stoplight
  module Domain
    module Strategies
      # Represents an abstract strategy for running a light's operations.
      # Every new strategy should be a child of this class.
      #
      # @api private
      # @abstract
      class RunStrategy
        # @param fallback [Proc, nil] A fallback proc to execute in case of an error.
        # @param metadata [Stoplight::Domain::Metadata] Metadata capturing the current state of the light.
        # :nocov:
        def execute(fallback, metadata:, &code)
          raise NotImplementedError, "Subclasses must implement the execute method"
        end
        # :nocov:

        # @return [Boolean]
        def ==(other)
          other.is_a?(self.class)
        end
      end
    end
  end
end
