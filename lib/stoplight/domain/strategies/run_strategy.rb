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
        # @param state_snapshot [Stoplight::Domain::StateSnapshot]
        # :nocov:
        def execute(fallback, state_snapshot:, &code)
          raise NotImplementedError, "Subclasses must implement the execute method"
        end
        # :nocov:
      end
    end
  end
end
