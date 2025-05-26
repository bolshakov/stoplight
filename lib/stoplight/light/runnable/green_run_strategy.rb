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
          # TODO: Consider implementing sampling rate to limit the memory footprint
          code.call.tap { record_success }
        rescue Exception => error # rubocop: disable Lint/RescueException
          if config.track_error?(error)
            record_error(error)

            if fallback
              fallback.call(error)
            else
              raise
            end
          else
            # User chose to not track the error, so we record it as a success
            record_success
            raise
          end
        end

        private def record_error(error)
          failure = Stoplight::Failure.from_error(error)
          metadata = data_store.record_failure(config, failure)

          if config.traffic_control.stop_traffic?(config, metadata) && data_store.transition_to_color(config, Color::RED)
            config.notifiers.each do |notifier|
              notifier.notify(config, Color::GREEN, Color::RED, error)
            end
          end
        end

        private def record_success
          data_store.record_success(config)
        end
      end
    end
  end
end
