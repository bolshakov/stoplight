# frozen_string_literal: true

module Stoplight
  module Wiring
    class LightFactory
      TrafficRecoveryDsl = ->(value) {
        case value
        in Domain::TrafficRecovery::Base
          value
        in :consecutive_successes
          Domain::TrafficRecovery::ConsecutiveSuccesses.new
        else
          raise Domain::Error::ConfigurationError, <<~ERROR
            unsupported traffic_recovery strategy provided (`#{value}`). Supported options:
              * :consecutive_successes
          ERROR
        end
      }
    end
  end
end
