# frozen_string_literal: true

module Stoplight
  module Wiring
    class LightConfigurationDsl
      TrafficControlDsl = ->(value) {
        case value
        in _ if value.respond_to?(:stop_traffic?) # TODO: can be removed in 6.0
          value
        in Domain::TrafficControl::ConsecutiveErrors::NAME
          Domain::TrafficControl::ConsecutiveErrors.new
        in Domain::TrafficControl::ErrorRate::NAME
          Domain::TrafficControl::ErrorRate.new
        else
          raise Stoplight::Error::ConfigurationError, <<~ERROR
            unsupported traffic_control strategy provided (`#{value}`). Supported options:
              * :consecutive_errors
              * :error_rate
          ERROR
        end
      }
    end
  end
end
