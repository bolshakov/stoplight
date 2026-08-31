# frozen_string_literal: true

module Stoplight
  module Wiring
    # Subscribes the legacy, user-facing +Notifier+ collaborators to the telemetry bus, so
    # +Domain::Light+'s collaborators never call notifiers directly.
    #
    # @api private
    class NotifierBridge
      def initialize(light_name:, notifiers:)
        @light_name = light_name
        @notifiers = notifiers
      end

      def subscribe(bus)
        bus.subscribe(Domain::Telemetry::TrafficBreached) { |envelope| notify(envelope, error: envelope.payload.failure&.exception) }
        bus.subscribe(Domain::Telemetry::RecoveryStarted) { |envelope| notify(envelope, error: nil) }
        bus.subscribe(Domain::Telemetry::RecoverySucceeded) { |envelope| notify(envelope, error: nil) }
        bus.subscribe(Domain::Telemetry::RecoveryFailed) { |envelope| notify(envelope, error: envelope.payload.failure&.exception) }
      end

      private

      def notify(envelope, error:)
        return unless envelope.light_name == @light_name

        info = Domain::LightInfo.new(name: @light_name)
        payload = envelope.payload

        @notifiers.each do |notifier|
          notifier.notify(info, payload.from_color, payload.to_color, error)
        end
      end
    end
  end
end
