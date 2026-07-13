# frozen_string_literal: true

module Stoplight
  module Domain
    module Tracker
      # Tracks request outcomes (success/failure) and manages state transitions
      # for normal traffic.
      #
      # Used by +GreenRunStrategy+ to track failures and potentially open the circuit.
      #
      # @api private
      class Request
        def initialize(traffic_control:, notifiers:, config:, metrics_store:, state_store:, emitter:)
          @traffic_control = traffic_control
          @notifiers = notifiers
          @config = config
          @metrics_store = metrics_store
          @state_store = state_store
          @emitter = emitter
        end

        def record_failure(exception)
          metrics_store.record_failure(exception)
          metrics = metrics_store.metrics_snapshot

          transition_to_red(exception, metrics:)
        end

        def record_success = metrics_store.record_success

        private

        attr_reader :traffic_control
        attr_reader :notifiers
        attr_reader :config
        attr_reader :metrics_store
        attr_reader :state_store
        attr_reader :emitter

        def transition_to_red(exception, metrics:)
          if traffic_control.stop_traffic?(config, metrics)
            # Returns true only if not yet in red therefore preventing
            # duplicate notifications
            if state_store.transition_to_color(Color::RED)
              info = LightInfo.new(name: config.name)
              notifiers.each do |notifier|
                notifier.notify(info, Color::GREEN, Color::RED, exception)
              end
              emitter.emit(Telemetry::TrafficBreached) do
                Telemetry::TrafficBreached.new(
                  from_color: Color::GREEN,
                  to_color: Color::RED,
                  policy: policy_name,
                  failure: Telemetry::Failure.new(exception:, tracked: true),
                  metrics: telemetry_metrics(metrics)
                )
              end
            end
          end
        end

        def policy_name
          traffic_control.class.to_s.split("::").last.gsub(/([a-z\d])([A-Z])/, "\\1_\\2").downcase
        end

        def telemetry_metrics(metrics)
          Telemetry::Metrics.new(
            successes: metrics.successes,
            errors: metrics.errors,
            consecutive_errors: metrics.consecutive_errors,
            consecutive_successes: metrics.consecutive_successes
          )
        end
      end
    end
  end
end
