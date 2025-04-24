# frozen_string_literal: true

module Stoplight
  class Light < CircuitBreaker
    module Runnable
      # Defines how the light executes when it is red.
      #
      # This strategy prevents execution of the code block and either raises an error
      # or invokes a fallback if provided.
      #
      # @api private
      class RedRunStrategy < RunStrategy
        # Executes the fallback proc when the light is in the red state.
        #
        # @param fallback [Proc, nil] A fallback proc to execute instead of the code block.
        # @return [Object, nil] The result of the fallback proc if provided.
        # @raise [Stoplight::Error::RedLight] Raises an error if no fallback is provided.
        def execute(fallback)
          if fallback
            fallback.call(nil)
          else
            raise Error::RedLight, config.name
          end
        end
      end
    end
  end
end
