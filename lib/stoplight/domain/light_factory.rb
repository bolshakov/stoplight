# frozen_string_literal: true

module Stoplight
  module Domain
    # Abstract factory protocol for building +Stoplight::Light+ instances.
    #
    # This defines the interface that any Light factory must implement,
    # regardless of the underlying implementation details.
    #
    # This uses the Abstract Factory pattern to decouple the domain (Light)
    # from the application layer (concrete factory implementation). Light
    # doesn't know HOW it's built, only that it needs something that can
    # build variants of itself.
    #
    # By defining this interface in the domain layer:
    # - Light can request reconfiguration without knowing about containers
    # - Different factory implementations can be swapped (code, database-configured, etc.)
    # - Dependency direction is preserved (Application → Domain, not Domain → Application)
    #
    # @abstract Subclasses must implement +#with+ and +#build+
    # @api private
    # steep:ignore:start
    class LightFactory
      # Creates a new factory with modified settings.
      #
      # This method must return a NEW factory instance - it should not
      # modify the current factory. The new factory should inherit all
      # configuration from the current factory, with the provided
      # settings overriding specific values.
      #
      # @param settings [Hash] Configuration and dependency overrides
      # @return [Stoplight::Domain::LightFactory] New factory with updated settings
      # @raise [NotImplementedError] Must be implemented by subclass
      # @abstract
      # :nocov:
      def with(
        name: T.undefined,
        cool_off_time: T.undefined,
        threshold: T.undefined,
        recovery_threshold: T.undefined,
        window_size: T.undefined,
        tracked_errors: T.undefined,
        skipped_errors: T.undefined,
        data_store: T.undefined,
        error_notifier: T.undefined,
        notifiers: T.undefined,
        traffic_control: T.undefined,
        traffic_recovery: T.undefined
      )
        raise NotImplementedError
      end

      # Builds a +Stoplight::Light+ instance with the current configuration.
      #
      # This method must construct a fully-wired Light with all required
      # dependencies (strategies, data store, notifiers, etc.). The Light
      # should be ready to use immediately after construction.
      #
      # @return [Stoplight::Light] Configured circuit breaker instance
      # @raise [NotImplementedError] Must be implemented by subclass
      # @raise [Stoplight::Error::ConfigurationError] If configuration is invalid
      # @abstract
      def build
        raise NotImplementedError
      end
      # :nocov:

      # Convenience method to configure and build in one operation.
      #
      # This combines +#with+ and +#build+ into a single call, which is
      # useful when you want to create a customized Light without keeping
      # a reference to the intermediate factory.
      #
      # @param settings [Hash] Settings to override before building
      # @return [Stoplight::Light] Configured circuit breaker instance
      #
      # @example Usage
      #   # Instead of:
      #   new_factory = factory.with(threshold: 10)
      #   light = new_factory.build
      #
      #   # You can do:
      #   light = factory.build_with(threshold: 10)
      def build_with(
        name: T.undefined,
        cool_off_time: T.undefined,
        threshold: T.undefined,
        recovery_threshold: T.undefined,
        window_size: T.undefined,
        tracked_errors: T.undefined,
        skipped_errors: T.undefined,
        data_store: T.undefined,
        error_notifier: T.undefined,
        notifiers: T.undefined,
        traffic_control: T.undefined,
        traffic_recovery: T.undefined
      )
        with(
          name:,
          cool_off_time:,
          threshold:,
          recovery_threshold:,
          window_size:,
          tracked_errors:,
          skipped_errors:,
          data_store:,
          error_notifier:,
          notifiers:,
          traffic_control:,
          traffic_recovery:
        ).build
      end
    end
    # steep:ignore:end
  end
end
