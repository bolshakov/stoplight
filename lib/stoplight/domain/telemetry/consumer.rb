# frozen_string_literal: true

module Stoplight
  module Domain
    module Telemetry
      # Consumer-only view of a telemetry bus - forwards subscribe/unsubscribe, never publish.
      class Consumer
        def initialize(telemetry)
          @telemetry = telemetry
        end

        def subscribe(...) = @telemetry.subscribe(...)

        def unsubscribe(...) = @telemetry.unsubscribe(...)
      end
    end
  end
end
