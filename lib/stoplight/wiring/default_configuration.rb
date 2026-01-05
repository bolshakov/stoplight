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
        @cool_off_time = Common.none
        @threshold = Common.none
        @recovery_threshold = Common.none
        @window_size = Common.none
        @tracked_errors = Common.none
        @skipped_errors = Common.none
        @traffic_control = Common.none
        @traffic_recovery = Common.none
        @error_notifier = Common.none
        @data_store = Common.none
        @notifiers = Common.none
      end

      def cool_off_time = @cool_off_time.get_or_else { Default::COOL_OFF_TIME }
      def threshold = @threshold.get_or_else { Default::THRESHOLD }
      def recovery_threshold = @recovery_threshold.get_or_else { Default::RECOVERY_THRESHOLD }
      def window_size = @window_size.get_or_else { Default::WINDOW_SIZE }
      def tracked_errors = @tracked_errors.get_or_else { Default::TRACKED_ERRORS }
      def skipped_errors = @skipped_errors.get_or_else { Default::SKIPPED_ERRORS }
      def traffic_control = @traffic_control.get_or_else { Default::TRAFFIC_CONTROL }
      def traffic_recovery = @traffic_recovery.get_or_else { Default::TRAFFIC_RECOVERY }
      def error_notifier = @error_notifier.get_or_else { Default::ERROR_NOTIFIER }
      def data_store = @data_store.get_or_else { Default::DATA_STORE }
      def notifiers = @notifiers.get_or_else { Default::NOTIFIERS }

      def cool_off_time=(value)
        @cool_off_time = Common.some(value)
      end

      def threshold=(value)
        @threshold = Common.some(value)
      end

      def recovery_threshold=(value)
        @recovery_threshold = Common.some(value)
      end

      def window_size=(value)
        @window_size = Common.some(value)
      end

      def tracked_errors=(value)
        @tracked_errors = Common.some(value)
      end

      def skipped_errors=(value)
        @skipped_errors = Common.some(value)
      end

      def traffic_control=(value)
        @traffic_control = Common.some(value)
      end

      def traffic_recovery=(value)
        @traffic_recovery = Common.some(value)
      end

      def error_notifier=(value)
        @error_notifier = Common.some(value)
      end

      def data_store=(value)
        @data_store = Common.some(value)
      end

      def notifiers=(value)
        @notifiers = Common.some(value)
      end

      def to_settings
        Settings.new(
          name: Common.none,
          cool_off_time: @cool_off_time,
          threshold: @threshold,
          recovery_threshold: @recovery_threshold,
          window_size: @window_size,
          tracked_errors: @tracked_errors,
          skipped_errors: @skipped_errors,
          traffic_control: @traffic_control,
          traffic_recovery: @traffic_recovery,
          error_notifier: @error_notifier,
          notifiers: @notifiers,
          data_store: @data_store
        )
      end
    end
  end
end
