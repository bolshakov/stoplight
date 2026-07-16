# frozen_string_literal: true

module Stoplight
  module Domain
    # In-process telemetry bus
    class Telemetry
      # Value-level mirror of the +event+ union.
      EVENT_CLASSES = [
        RunCompleted,
        TrafficBreached,
        RecoveryStarted,
        RecoverySucceeded,
        RecoveryFailed,
        LockChanged,
        RecoveryProbeCompleted,
        LightRegistered
      ].freeze

      MAX_SUBSCRIPTIONS = 1_000

      def initialize(error_notifier:, max_subscriptions: MAX_SUBSCRIPTIONS)
        @mutex = Mutex.new
        @error_notifier = error_notifier
        @max_subscriptions = max_subscriptions
        @subscriptions = []
        rebuild
      end

      def subscribe(filter = nil, &handler)
        raise ArgumentError, "nothing to subscribe. Please, pass a block into `Telemetry#subscribe`" unless handler
        raise ArgumentError, "filter must be nil or a Module, got #{filter.inspect}" unless filter.nil? || filter.is_a?(Module)

        subscription = Subscription.new
        @mutex.synchronize do
          if @subscriptions.size >= @max_subscriptions
            raise Stoplight::Error::TooManySubscriptions, "exceeded #{@max_subscriptions} telemetry subscriptions"
          end

          @subscriptions << [subscription, filter, handler]
          rebuild
        end
        subscription
      end

      def unsubscribe(subscription)
        @mutex.synchronize do
          @subscriptions.reject! { |token, _, _| token.equal?(subscription) }
          rebuild
        end
        nil
      end

      def subscribed?(event_class)
        @dispatch.key?(event_class)
      end

      def publish(envelope)
        @dispatch[envelope.payload.class]&.each do |handler|
          handler.call(envelope)
        rescue => error
          begin
            @error_notifier.call(error)
          rescue => notifier_error
            warn "Stoplight telemetry error_notifier raised: #{notifier_error.message}"
          end
        end
        nil
      end

      # Called under @mutex. Resolves every filter (nil = firehose, module, or exact class) against the closed set of
      # concrete classes and swaps in a frozen table - copy-on-write, so publish never sees a table mid-mutation and
      # needs no lock.
      private def rebuild
        table = {} #: Hash[Class, Array[untyped]]
        EVENT_CLASSES.each do |event_class|
          handlers = @subscriptions.filter_map do |_, filter, handler|
            handler if filter.nil? || event_class <= filter
          end
          table[event_class] = handlers.freeze unless handlers.empty?
        end
        @dispatch = table.freeze
      end
    end
  end
end
