# frozen_string_literal: true

module Stoplight
  module Domain
    class Telemetry
      class Emitter
        def initialize(bus:, clock:, system_name:, light_name:)
          @bus = bus
          @clock = clock
          @system_name = system_name
          @light_name = light_name
        end

        # Emits telemetry event.
        def emit(event_class)
          return unless @bus.subscribed?(event_class)

          @bus.publish(
            Envelope.new(
              light_name: @light_name,
              system_name: @system_name,
              occurred_at: @clock.current_time,
              payload: yield
            )
          )
        end
      end
    end
  end
end
