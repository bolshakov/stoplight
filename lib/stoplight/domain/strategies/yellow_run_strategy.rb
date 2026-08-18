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
        def initialize(
          name:,
          notifiers:,
          request_tracker:,
          state_store:,
          metrics_store:,
          recovery_lock_store:,
          config:, # FIXME: needed for backward compatibility, remove when notifier accepts light config
          clock:,
          run_recorder:
        )
          @notifiers = notifiers
          @request_tracker = request_tracker
          @state_store = state_store
          @metrics_store = metrics_store
          @recovery_lock_store = recovery_lock_store
          @name = name
          @config = config
          @clock = clock
          @run_recorder = run_recorder
        end

        # Executes the provided code block when the light is in the yellow state.
        #
        # @param fallback A fallback proc to execute in case of an error.
        # @param state_snapshot
        # @yield The code block to execute.
        # @return The result of the code block if successful.
        # @raise Re-raises the error if it is not tracked or no fallback is provided.
        def execute(fallback, state_snapshot:, error_tracking_policy:, &code)
          # Everything withing this block executed exclusively:
          #   - enter recovery
          #   - execute user's code
          #   - record outcome
          #   - transition to green or red if needed
          with_recovery_lock(fallback:, state_snapshot:) do |started_at|
            enter_recovery(state_snapshot)

            begin
              result = code.call
            rescue => error
              if error_tracking_policy.track?(error)
                record_recovery_probe_failure(error, duration_ms: duration_since(started_at), fallback_used: !fallback.nil?)

                if fallback
                  fallback.call(error)
                else
                  raise
                end
              else
                record_recovery_probe_success(duration_ms: duration_since(started_at), error:)
                raise
              end
            else
              record_recovery_probe_success(duration_ms: duration_since(started_at))
              result
            end
          end
        end

        private

        attr_reader :notifiers
        attr_reader :request_tracker
        attr_reader :state_store
        attr_reader :metrics_store
        attr_reader :recovery_lock_store

        def with_recovery_lock(fallback:, state_snapshot:)
          recovery_lock_token = recovery_lock_store.acquire_lock
          if recovery_lock_token.nil?
            @run_recorder.record_blocked(
              fallback_used: !fallback.nil?,
              retry_after: state_snapshot.recovery_scheduled_after
            )

            return fallback.call(nil) if fallback

            raise Error::RedLight.new(
              @name,
              cool_off_time: @config.cool_off_time,
              retry_after: state_snapshot.recovery_scheduled_after
            )
          end

          begin
            yield capture_started_at
          ensure
            recovery_lock_store.release_lock(recovery_lock_token)
          end
        end

        def capture_started_at
          @clock.monotonic_time if @run_recorder.subscribed? || request_tracker.subscribed?
        end

        def duration_since(started_at)
          @clock.monotonic_time - started_at if started_at
        end

        def record_recovery_probe_success(duration_ms:, error: nil)
          @run_recorder.record_success(duration_ms:, error:)
          request_tracker.record_success(duration_ms:)
        end

        def record_recovery_probe_failure(error, duration_ms:, fallback_used:)
          @run_recorder.record_failure(error, duration_ms:, fallback_used:)
          request_tracker.record_failure(error, duration_ms:)
        end

        def enter_recovery(state_snapshot)
          return if state_snapshot.recovery_started?

          state_store.transition_to_color(Color::YELLOW)
          metrics_store.clear
          light_info = LightInfo.new(name: @name)
          notifiers.each do |notifier|
            notifier.notify(light_info, Color::RED, Color::YELLOW, nil)
          end
        end
      end
    end
  end
end
