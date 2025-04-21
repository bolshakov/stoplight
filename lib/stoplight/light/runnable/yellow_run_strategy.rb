# frozen_string_literal: true

module Stoplight
  class Light < CircuitBreaker
    module Runnable
      # Defines how the light executes when it is yellow.
      #
      # This strategy clears failures after successful execution and notifies
      # about color switch from Red to Green. It also handles errors by either
      # raising them or invoking a fallback if provided.
      #
      # @api private
      class YellowRunStrategy < RunStrategy
        # Executes the provided code block when the light is in the yellow state.
        #
        # @param fallback [Proc, nil] A fallback proc to execute in case of an error.
        # @yield The code block to execute.
        # @return [Object] The result of the code block if successful.
        # @raise [Exception] Re-raises the error if it is not tracked or no fallback is provided.
        def execute(fallback, &code)
          code.call.tap do
            failures = data_store.clear_failures(config)
            notify(config, Color::RED, Color::GREEN) unless failures.empty?
          end
        rescue Exception => error # rubocop: disable Lint/RescueException
          raise unless config.track_error?(error)

          if fallback
            fallback.call(error)
          else
            raise
          end
        end
      end
    end
  end
end
