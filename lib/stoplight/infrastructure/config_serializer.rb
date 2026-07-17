# frozen_string_literal: true

module Stoplight
  module Infrastructure
    class ConfigSerializer
      class << self
        def call(config)
          {
            "cool_off_time" => config.cool_off_time,
            "threshold" => config.threshold,
            "recovery_threshold" => config.recovery_threshold,
            "window_size" => config.window_size,
            "tracked_errors" => config.tracked_errors.map(&:name),
            "skipped_errors" => config.skipped_errors.map(&:name),
            "traffic_control" => {
              "strategy" => serialize_traffic_control(config.traffic_control)
            },
            "traffic_recovery" => {
              "strategy" => serialize_traffic_recovery(config.traffic_recovery)
            }
          }
        end

        private

        def serialize_traffic_control(traffic_control)
          case traffic_control
          when Domain::TrafficControl::ConsecutiveErrors
            Domain::TrafficControl::ConsecutiveErrors::NAME.to_s
          when Domain::TrafficControl::ErrorRate
            Domain::TrafficControl::ErrorRate::NAME.to_s
          else
            raise TypeError, "unable to serialize traffic_control: #{traffic_control}"
          end
        end

        def serialize_traffic_recovery(traffic_recovery)
          case traffic_recovery
          when Domain::TrafficRecovery::ConsecutiveSuccesses
            Domain::TrafficRecovery::ConsecutiveSuccesses::NAME.to_s
          else
            raise TypeError, "unable to serialize traffic_recovery: #{traffic_recovery}"
          end
        end
      end
    end
  end
end
