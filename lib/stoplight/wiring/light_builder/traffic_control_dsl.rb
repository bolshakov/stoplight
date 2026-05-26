# frozen_string_literal: true

module Stoplight
  module Wiring
    class LightBuilder
      TrafficControlDsl = ->(value) {
        case value
        in _ if value.respond_to?(:stop_traffic?) # TODO: can be removed in 6.0
          value
        in :consecutive_errors
          Domain::TrafficControl::ConsecutiveErrors.new
        in :error_rate
          Domain::TrafficControl::ErrorRate.new
        in {error_rate: error_rate_settings}
          Domain::TrafficControl::ErrorRate.new(**error_rate_settings)
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
