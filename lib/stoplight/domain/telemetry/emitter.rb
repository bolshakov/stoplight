# frozen_string_literal: true

module Stoplight
  module Domain
    class Telemetry
      class Emitter
        def initialize(bus:, clock:, system_name:, light_name:, error_notifier:)
          @bus = bus
          @clock = clock
          @system_name = system_name
          @light_name = light_name
          @error_notifier = error_notifier
        end

        # True when any subscriber would receive this event class.
        def subscribed?(event_class) = @bus.subscribed?(event_class)

        # Emits telemetry event. A failure to build or publish it is routed to the error
        # notifier, never to the caller - the same isolation the bus gives subscriber handlers.
        def emit(event_class)
          return unless subscribed?(event_class)

          @bus.publish(
            Envelope.new(
              light_name: @light_name,
              system_name: @system_name,
              occurred_at: @clock.current_time,
              payload: yield
            )
          )
        rescue => error
          notify_error(error)
        end

        private

        def notify_error(error)
          @error_notifier.call(error)
        rescue => notifier_error
          warn "Stoplight telemetry error_notifier raised: #{notifier_error.message}"
        end
      end
    end
  end
end
