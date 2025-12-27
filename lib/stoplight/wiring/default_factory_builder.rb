# frozen_string_literal: true

module Stoplight
  module Wiring
    # Builds the default LightFactory from user-provided configuration which is
    # used as the basis for all circuit breakers.
    #
    class DefaultFactoryBuilder
      # @!attribute [r] configuration
      #  @return [Stoplight::Wiring::DefaultConfiguration]
      #
      # @dynamic configuration
      attr_reader :configuration

      def initialize
        @configuration = DefaultConfiguration.new
      end

      # @return [Stoplight::Wiring::LightFactory]
      # @api private the method is used internally by Stoplight
      def build
        LightFactory.new(
          {
            cool_off_time: configuration.cool_off_time,
            threshold: configuration.threshold,
            recovery_threshold: configuration.recovery_threshold,
            window_size: configuration.window_size,
            tracked_errors: configuration.tracked_errors,
            skipped_errors: configuration.skipped_errors,
            data_store: configuration.data_store,
            error_notifier: configuration.error_notifier,
            notifiers: configuration.notifiers,
            traffic_control: configuration.traffic_control,
            traffic_recovery: configuration.traffic_recovery
          }.compact
        )
      end
    end
  end
end
