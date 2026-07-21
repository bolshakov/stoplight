# frozen_string_literal: true

module Stoplight
  module Domain
    module Strategies
      # Defines how the light executes when it is green.
      #
      # This strategy clears failures after successful execution and handles errors
      # by either raising them or invoking a fallback if provided.
      #
      # @api private
      class GreenRunStrategy
        def initialize(request_tracker:, run_recorder:, clock:)
          @request_tracker = request_tracker
          @run_recorder = run_recorder
          @clock = clock
        end

        # Executes the provided code block when the light is in the green state.
        #
        # @param fallback A fallback proc to execute in case of an error.
        # @param state_snapshot
        # @yield The code block to execute.
        # @return The result of the code block if successful.
        # @raise re-raises the error if it is not tracked or no fallback is provided.
        def execute(fallback, state_snapshot:, error_tracking_policy:, &code)
          started_at = capture_started_at

          begin
            result = code.call
          rescue => error
            if error_tracking_policy.track?(error)
              record_error(error, duration_ms: duration_since(started_at), fallback_used: !fallback.nil?)

              if fallback
                fallback.call(error)
              else
                raise
              end
            else
              # User chose to not track the error, so we record it as a success
              record_success(duration_ms: duration_since(started_at), error: error)
              raise
            end
          else
            record_success(duration_ms: duration_since(started_at))
            result
          end
        end

        private

        attr_reader :request_tracker

        def capture_started_at
          @clock.monotonic_time if @run_recorder.subscribed?
        end

        def duration_since(started_at)
          @clock.monotonic_time - started_at if started_at
        end

        def record_error(error, duration_ms:, fallback_used:)
          @run_recorder.record_failure(error, duration_ms:, fallback_used:)
          request_tracker.record_failure(error)
        end

        def record_success(duration_ms:, error: nil)
          @run_recorder.record_success(duration_ms:, error:)
          request_tracker.record_success
        end
      end
    end
  end
end
