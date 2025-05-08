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
          # We need to employ a probabilistic approach here to avoid "thundering herd" problem
          code.call.tap { record_recovery_probe_success }
        rescue Exception => error # rubocop: disable Lint/RescueException
          if config.track_error?(error)
            record_recovery_probe_failure(error)

            if fallback
              fallback.call(error)
            else
              raise
            end
          else
            record_recovery_probe_success
            raise
          end
        end

        private def record_recovery_probe_success
          metadata = data_store.record_recovery_probe_success(config)

          recover(metadata)
        end

        private def record_recovery_probe_failure(error)
          failure = Failure.from_error(error)
          metadata = data_store.record_recovery_probe_failure(config, failure)

          recover(metadata)
        end

        private def recover(metadata)
          recovery_result = config.recovery_strategy.evaluate(config, metadata)

          case recovery_result
          when Color::GREEN
            if data_store.transition_to_color(config, Color::GREEN)
              config.notifiers.each do |notifier|
                notifier.notify(config, Color::RED, Color::GREEN, nil)
              end
            end
          when Color::YELLOW
            # No action needed, just a successful probe
          when Color::RED
            if data_store.transition_to_color(config, Color::RED)
              config.notifiers.each do |notifier|
                notifier.notify(config, Color::YELLOW, Color::RED, nil)
              end
            end
          else
            raise "recovery strategy returned an expected color: #{recovery_result}"
          end
        end
      end
    end
  end
end
