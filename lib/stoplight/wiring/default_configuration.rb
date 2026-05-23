# frozen_string_literal: true

module Stoplight
  module Wiring
    # User-facing configuration interface for setting global Stoplight defaults.
    #
    # This class serves as the configuration DSL yielded to users when calling
    # +Stoplight.configure+. It provides a clean interface for setting default
    # values while internally tracking whether each setting was explicitly
    # configured or should fall back to library defaults.
    #
    # @example Configuring Stoplight defaults
    #   Stoplight.configure do |config|
    #     config.data_store = Redis.new
    #     config.threshold = 5
    #     # window_size not set - will use library default
    #   end
    #
    # == Option-Based Configuration Tracking
    #
    # Internally, each setting is wrapped in an Option type (+Some+ or +None+).
    # This design allows the class to distinguish between three states:
    #
    # 1. Not configured: Stored as +None+, getter returns library default
    # 2. Explicitly configured: Stored as +Some(value)+, getter returns that value
    # 3. Explicitly set to nil: Stored as +Some(nil)+, getter returns +nil+
    #
    # This distinction is critical when building {Settings} and {Dependencies}
    # objects, which need to know whether a value was user-specified (and should
    # be enforced) or inherited (and can be overridden per-circuit).
    #
    # == Dual Interface
    #
    # The class exposes two interfaces for each setting:
    #
    # - *Setters* (+attr_writer+): Accept raw values, wrap them in +Some+
    # - *Getters* (custom methods): Unwrap the Option, returning the value
    #   or falling back to library defaults from {Default}
    #
    # The {#settings} and {#dependencies} methods preserve the raw Option
    # values, allowing downstream code to detect explicit configuration.
    #
    # @see Settings Value object for circuit behavior configuration
    # @see Dependencies Value object for infrastructure dependencies
    # @see Default Library default constants
    #
    class DefaultConfiguration
      def initialize
        @config = DefaultConfig.with
        @cool_off_time = T.undefined
        @threshold = T.undefined
        @recovery_threshold = T.undefined
        @window_size = T.undefined
        @tracked_errors = T.undefined
        @skipped_errors = T.undefined
        @traffic_control = T.undefined
        @traffic_recovery = T.undefined
        @error_notifier = T.undefined
        @data_store = T.undefined
        @notifiers = T.undefined
      end

      def notifiers = @config.notifiers

      attr_writer :cool_off_time
      attr_writer :threshold
      attr_writer :recovery_threshold
      attr_writer :window_size
      attr_writer :tracked_errors
      attr_writer :skipped_errors
      attr_writer :traffic_control
      attr_writer :traffic_recovery
      attr_writer :error_notifier
      attr_writer :data_store
      attr_writer :notifiers

      # Builds and validates configuration
      def to_config!
        LegacyConfigurationDsl.new(
          cool_off_time: @cool_off_time,
          threshold: @threshold,
          recovery_threshold: @recovery_threshold,
          window_size: @window_size,
          tracked_errors: @tracked_errors,
          skipped_errors: @skipped_errors,
          traffic_control: @traffic_control,
          traffic_recovery: @traffic_recovery,
          error_notifier: @error_notifier,
          data_store: @data_store,
          notifiers: @notifiers
        ).configure!(@config)
      end
    end
  end
end
