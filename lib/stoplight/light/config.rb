# frozen_string_literal: true

module Stoplight
  class Light
    # A +Stoplight::Light+ configuration object.
    #
    # # @!attribute [r] name
    #   @return [String]
    #
    # @!attribute [r] cool_off_time
    #   @return [Numeric]
    #
    # @!attribute [r] data_store
    #   @return [Stoplight::DataStore::Base]
    #
    # @!attribute [r] error_notifier
    #   @return [StandardError => void]
    #
    # @!attribute [r] notifiers
    #   @return [Array<Stoplight::Notifier::Base>]
    #
    # @!attribute [r] threshold
    #   @return [Numeric]
    #
    # @!attribute [r] window_size
    #   @return [Numeric]
    #
    # @!attribute [r] tracked_errors
    #   @return [Array<StandardError>]
    #
    # @!attribute [r] skipped_errors
    #  @return [Array<Exception>]
    #
    # @!attribute [r] traffic_control
    #  @return [Stoplight::TrafficControl::Base]
    #
    # @!attribute [r] traffic_recovery
    #   @return [Stoplight::TrafficRecovery::Base]
    # @api private
    Config = Data.define(
      :name,
      :cool_off_time,
      :data_store,
      :error_notifier,
      :notifiers,
      :threshold,
      :window_size,
      :tracked_errors,
      :skipped_errors,
      :traffic_control,
      :traffic_recovery
    ) do
      class << self
        # Creates a new NULL configuration object.
        # @return [Stoplight::Light::Config]
        def empty
          new(**members.map { |key| [key, nil] }.to_h)
        end
      end

      # Checks if the given error should be tracked
      #
      # @param error [#==] The error to check, e.g. an Exception, Class or Proc
      # @return [Boolean]
      def track_error?(error)
        skip = skipped_errors.any? { |klass| klass === error }
        track = tracked_errors.any? { |klass| klass === error }

        !skip && track
      end

      # This method applies configuration dsl and revalidates the configuration
      # @return [Stoplight::Light::Config]
      def with(**settings)
        super(**CONFIG_DSL.transform(settings)).then do |config|
          config.validate_config!
        end
      end

      # @raise [Stoplight::Error::ConfigurationError]
      # @return [Stoplight::Light::Config] The validated configuration object.
      def validate_config!
        validate_traffic_control_compatibility!
        self
      end

      private

      def validate_traffic_control_compatibility!
        traffic_control.check_compatibility(self).then do |compatibility_result|
          if compatibility_result.incompatible?
            raise Stoplight::Error::ConfigurationError.new(
              "#{traffic_control.class.name} strategy is incompatible with the Stoplight configuration: #{compatibility_result.error_messages}"
            )
          end
        end
      end
    end
  end
end
