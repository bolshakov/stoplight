# frozen_string_literal: true

module Stoplight
  module Domain
    module Telemetry
      # Builds and emits RunCompleted events for one light color.
      #
      # @api private
      class RunRecorder
        def initialize(emitter:, color:)
          @emitter = emitter
          @color = color
        end

        # True when any subscriber would receive a RunCompleted event.
        def subscribed? = @emitter.subscribed?(RunCompleted)

        def record_success(duration_ms:, error: nil)
          emit(
            outcome: :success,
            duration_ms:,
            failure: error && Failure.new(exception: error, tracked: false),
            fallback_used: false,
            retry_after: nil
          )
        end

        def record_failure(error, duration_ms:, fallback_used:)
          emit(
            outcome: :failure,
            duration_ms:,
            failure: Failure.new(exception: error, tracked: true),
            fallback_used:,
            retry_after: nil
          )
        end

        def record_blocked(fallback_used:, retry_after:)
          emit(
            outcome: :blocked,
            duration_ms: nil,
            failure: nil,
            fallback_used:,
            retry_after:
          )
        end

        private

        def emit(outcome:, duration_ms:, failure:, fallback_used:, retry_after:)
          @emitter.emit(RunCompleted) do
            RunCompleted.new(outcome:, color: @color, duration_ms:, failure:, fallback_used:, retry_after:)
          end
        end
      end
    end
  end
end
