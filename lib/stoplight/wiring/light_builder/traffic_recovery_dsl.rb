# frozen_string_literal: true

module Stoplight
  module Wiring
    class LightBuilder
      TrafficRecoveryDsl = ->(value) {
        case value
        in _ if value.respond_to?(:determine_color) # TODO: remove in 6.0
          value
        in :consecutive_successes
          Domain::TrafficRecovery::ConsecutiveSuccesses.new
        else
          raise Error::ConfigurationError, <<~ERROR
            unsupported traffic_recovery strategy provided (`#{value}`). Supported options:
              * :consecutive_successes
          ERROR
        end
      }
    end
  end
end
