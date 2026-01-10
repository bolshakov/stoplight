# frozen_string_literal: true

module Stoplight
  module Domain
    module Strategies
      # Defines how the light executes when it is yellow.
      #
      # This strategy clears failures after successful execution and notifies
      # about color switch from Red to Green. It also handles errors by either
      # raising them or invoking a fallback if provided.
      #
      # @api private
      class YellowRunStrategy
        def initialize(config:, notifiers:, request_tracker:, red_run_strategy:, state_store:, metrics_store:, recovery_lock_store:)
          @config = config
          @notifiers = notifiers
          @request_tracker = request_tracker
          @red_run_strategy = red_run_strategy
          @state_store = state_store
          @metrics_store = metrics_store
          @recovery_lock_store = recovery_lock_store
        end

        # Executes the provided code block when the light is in the yellow state.
        #
        # @param fallback A fallback proc to execute in case of an error.
        # @param state_snapshot
        # @yield The code block to execute.
        # @return The result of the code block if successful.
        # @raise Re-raises the error if it is not tracked or no fallback is provided.
        def execute(fallback, state_snapshot:, &code)
          # Everything withing this block executed exclusively:
          #   - enter recovery
          #   - execute user's code
          #   - record outcome
          #   - transition to green or red if needed
          with_recovery_lock(fallback:, state_snapshot:, code:) do
            enter_recovery(state_snapshot)

            result = code.call
            record_recovery_probe_success
            result
          rescue => error
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
        end

        private

        attr_reader :config
        attr_reader :notifiers
        attr_reader :request_tracker
        attr_reader :red_run_strategy
        attr_reader :state_store
        attr_reader :metrics_store
        attr_reader :recovery_lock_store

        def with_recovery_lock(fallback:, state_snapshot:, code:)
          recovery_lock_token = recovery_lock_store.acquire_lock
          if recovery_lock_token.nil?
            return red_run_strategy.execute(fallback, state_snapshot:, &code)
          end

          begin
            yield
          ensure
            recovery_lock_store.release_lock(recovery_lock_token)
          end
        end

        def record_recovery_probe_success
          request_tracker.record_success
        end

        def record_recovery_probe_failure(error)
          request_tracker.record_failure(error)
        end

        def enter_recovery(state_snapshot)
          return if state_snapshot.recovery_started?

          state_store.transition_to_color(Color::YELLOW)
          metrics_store.clear
          notifiers.each do |notifier|
            notifier.notify(config, Color::RED, Color::YELLOW, nil)
          end
        end
      end
    end
  end
end
