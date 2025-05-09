# frozen_string_literal: true

module Stoplight
  class Light < CircuitBreaker
    module Runnable
      # Defines how the light executes when it is green.
      #
      # This strategy clears failures after successful execution and handles errors
      # by either raising them or invoking a fallback if provided.
      #
      # @api private
      class GreenRunStrategy < RunStrategy
        # Executes the provided code block when the light is in the green state.
        #
        # @param fallback [Proc, nil] A fallback proc to execute in case of an error.
        # @yield The code block to execute.
        # @return [Object] The result of the code block if successful.
        # @raise [Exception] Re-raises the error if it is not tracked or no fallback is provided.
        def execute(fallback, &code)
          code.call.tap do
            data_store.clear_failures(config)
          end
        rescue Exception => error # rubocop: disable Lint/RescueException
          raise unless config.track_error?(error)
          record_error(error)

          if fallback
            fallback.call(error)
          else
            raise
          end
        end

        # Records an error and notifies if the error threshold is exceeded.
        #
        # @param error [Exception] The error to record.
        # @return [void]
        private def record_error(error)
          failure = Failure.from_error(error)
          successes, failures = data_store.record_failure(config, failure)
          number_of_failures_in_a_row = (successes > 0) ? 0 : failures

          if config.threshold_exceeded?(number_of_failures_in_a_row)
            notify(config, Color::GREEN, Color::RED, error)
          end
        end
      end
    end
  end
end
