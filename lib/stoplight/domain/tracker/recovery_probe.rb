# frozen_string_literal: true

module Stoplight
  module Domain
    module Tracker
      class RecoveryProbe
        def initialize(traffic_recovery:, config:, metrics_store:, state_store:, emitter:)
          @traffic_recovery = traffic_recovery
          @config = config
          @metrics_store = metrics_store
          @state_store = state_store
          @emitter = emitter
        end

        def record_failure(exception, duration_ms:)
          metrics_store.record_failure(exception)

          recover(duration_ms:, exception:)
        end

        def record_success(duration_ms:)
          metrics_store.record_success

          recover(duration_ms:, exception: nil)
        end

        private

        attr_reader :traffic_recovery
        attr_reader :config
        attr_reader :metrics_store
        attr_reader :state_store
        attr_reader :emitter

        def recover(duration_ms:, exception:)
          recovery_metrics = metrics_store.metrics_snapshot

          emitter.emit(Telemetry::RecoveryProbeCompleted) do
            failure = exception ? Telemetry::Failure.new(exception:, tracked: true) : nil
            Telemetry::RecoveryProbeCompleted.new(
              outcome: failure ? :failure : :success,
              duration_ms:,
              failure:,
              progress: Telemetry::Metrics.new(
                successes: recovery_metrics.successes,
                errors: recovery_metrics.errors,
                consecutive_errors: recovery_metrics.consecutive_errors,
                consecutive_successes: recovery_metrics.consecutive_successes
              )
            )
          end

          recovery_result = traffic_recovery.determine_color(config, recovery_metrics)

          return if recovery_result == TrafficRecovery::YELLOW

          case recovery_result
          when TrafficRecovery::GREEN
            to_color = Color::GREEN
            if transition(to_color:)
              emitter.emit(Telemetry::RecoverySucceeded) do
                Telemetry::RecoverySucceeded.new(from_color: Color::YELLOW, to_color:,
                  policy: traffic_recovery.name,
                  metrics: Telemetry::Metrics.new(
                    successes: recovery_metrics.successes,
                    errors: recovery_metrics.errors,
                    consecutive_errors: recovery_metrics.consecutive_errors,
                    consecutive_successes: recovery_metrics.consecutive_successes
                  ))
              end
            end
          when TrafficRecovery::RED
            to_color = Color::RED
            if transition(to_color:)
              emitter.emit(Telemetry::RecoveryFailed) do
                Telemetry::RecoveryFailed.new(
                  from_color: Color::YELLOW,
                  to_color:,
                  policy: traffic_recovery.name,
                  failure: exception ? Telemetry::Failure.new(exception:, tracked: true) : nil,
                  metrics: Telemetry::Metrics.new(
                    successes: recovery_metrics.successes,
                    errors: recovery_metrics.errors,
                    consecutive_errors: recovery_metrics.consecutive_errors,
                    consecutive_successes: recovery_metrics.consecutive_successes
                  )
                )
              end
            end
          else
            raise "recovery strategy returned unexpected color: #{recovery_result}"
          end
        end

        def transition(to_color:)
          return false unless state_store.transition_to_color(to_color)
          metrics_store.clear
          true
        end
      end
    end
  end
end
