# frozen_string_literal: true

module Stoplight
  module Domain
    module Tracker
      class RecoveryProbe
        def initialize(traffic_recovery:, notifiers:, config:, metrics_store:, state_store:, emitter:)
          @traffic_recovery = traffic_recovery
          @notifiers = notifiers
          @config = config
          @metrics_store = metrics_store
          @state_store = state_store
          @emitter = emitter
        end

        # True when any subscriber would receive a RecoveryProbeCompleted event.
        def subscribed? = emitter.subscribed?(Telemetry::RecoveryProbeCompleted)

        # @param exception [Exception]
        def record_failure(exception, duration_ms:)
          metrics_store.record_failure(exception)

          recover(outcome: :failure, duration_ms:, failure: Telemetry::Failure.new(exception:, tracked: true))
        end

        def record_success(duration_ms:)
          metrics_store.record_success

          recover(outcome: :success, duration_ms:, failure: nil)
        end

        private

        attr_reader :traffic_recovery
        attr_reader :notifiers
        attr_reader :config
        attr_reader :metrics_store
        attr_reader :state_store
        attr_reader :emitter

        def recover(outcome:, duration_ms:, failure:)
          recovery_metrics = metrics_store.metrics_snapshot

          # Fires on every probe, whatever the outcome - it's a per-probe measurement, not a
          # state transition, so there's no dedup guard here.
          emitter.emit(Telemetry::RecoveryProbeCompleted) do
            Telemetry::RecoveryProbeCompleted.new(
              outcome:, duration_ms:, failure:,
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
            if transition(from_color: Color::YELLOW, to_color:)
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
            transition(from_color: Color::YELLOW, to_color: Color::RED)
          else
            raise "recovery strategy returned unexpected color: #{recovery_result}"
          end
        end

        def transition(from_color:, to_color:)
          return false unless state_store.transition_to_color(to_color)
          metrics_store.clear
          info = LightInfo.new(name: config.name)
          notifiers.each do |notifier|
            notifier.notify(info, from_color, to_color, nil)
          end
          true
        end
      end
    end
  end
end
