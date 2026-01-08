# frozen_string_literal: true

module Stoplight
  module Wiring
    # Intermediate representation of user-provided configuration.
    #
    # Unlike {Domain::Config} which holds resolved, validated values,
    # Settings wraps each field in an Option type to track whether
    # the user explicitly provided it.
    #
    # == Lifecycle
    #
    #   User DSL-→ Settings (Option-wrapped)-→ Config (resolved values)
    #
    # == Example
    #
    #   # User provides only threshold
    #   settings = Settings.empty.extend_with(name: "api", threshold: 5)
    #   settings.threshold      #=> Some(5)
    #   settings.window_size    #=> None
    #
    #   # ConfigurationPipeline resolves None to defaults
    #   config.threshold        #=> 5
    #   config.window_size      #=> nil (library default)
    #
    # @see Domain::Config Resolved configuration value object
    #
    class Settings
      attr_reader :name
      attr_reader :cool_off_time
      attr_reader :threshold
      attr_reader :recovery_threshold
      attr_reader :window_size
      attr_reader :skipped_errors
      attr_reader :tracked_errors
      attr_reader :traffic_control
      attr_reader :traffic_recovery
      attr_reader :error_notifier
      attr_reader :notifiers
      attr_reader :data_store

      class << self
        def empty = EMPTY
      end

      def initialize(
        name:,
        cool_off_time:,
        threshold:,
        recovery_threshold:,
        window_size:,
        skipped_errors:,
        tracked_errors:,
        traffic_control:,
        traffic_recovery:,
        error_notifier:,
        notifiers:,
        data_store:
      )
        @name = name
        @cool_off_time = cool_off_time
        @threshold = threshold
        @recovery_threshold = recovery_threshold
        @window_size = window_size
        @skipped_errors = skipped_errors
        @tracked_errors = tracked_errors
        @traffic_control = traffic_control
        @traffic_recovery = traffic_recovery
        @error_notifier = error_notifier
        @notifiers = notifiers
        @data_store = data_store
      end

      EMPTY = Settings.new(
        name: Common.none,
        cool_off_time: Common.none,
        threshold: Common.none,
        recovery_threshold: Common.none,
        window_size: Common.none,
        skipped_errors: Common.none,
        tracked_errors: Common.none,
        traffic_control: Common.none,
        traffic_recovery: Common.none,
        error_notifier: Common.none,
        notifiers: Common.none,
        data_store: Common.none
      )

      def extend_with(
        name: T.undefined,
        cool_off_time: T.undefined,
        threshold: T.undefined,
        recovery_threshold: T.undefined,
        window_size: T.undefined,
        skipped_errors: T.undefined,
        tracked_errors: T.undefined,
        traffic_control: T.undefined,
        traffic_recovery: T.undefined,
        error_notifier: T.undefined,
        notifiers: T.undefined,
        data_store: T.undefined
      )
        Settings.new(
          name: name.is_a?(Undefined) ? @name : Common.some(name),
          cool_off_time: cool_off_time.is_a?(Undefined) ? @cool_off_time : Common.some(cool_off_time),
          threshold: threshold.is_a?(Undefined) ? @threshold : Common.some(threshold),
          recovery_threshold: recovery_threshold.is_a?(Undefined) ? @recovery_threshold : Common.some(recovery_threshold),
          window_size: window_size.is_a?(Undefined) ? @window_size : Common.some(window_size),
          skipped_errors: skipped_errors.is_a?(Undefined) ? @skipped_errors : Common.some(skipped_errors),
          tracked_errors: tracked_errors.is_a?(Undefined) ? @tracked_errors : Common.some(tracked_errors),
          traffic_control: traffic_control.is_a?(Undefined) ? @traffic_control : Common.some(traffic_control),
          traffic_recovery: traffic_recovery.is_a?(Undefined) ? @traffic_recovery : Common.some(traffic_recovery),
          error_notifier: error_notifier.is_a?(Undefined) ? @error_notifier : Common.some(error_notifier),
          notifiers: notifiers.is_a?(Undefined) ? @notifiers : Common.some(notifiers),
          data_store: data_store.is_a?(Undefined) ? @data_store : Common.some(data_store)
        )
      end

      def empty?
        @name == Common.none &&
          @cool_off_time == Common.none &&
          @threshold == Common.none &&
          @recovery_threshold == Common.none &&
          @window_size == Common.none &&
          @skipped_errors == Common.none &&
          @tracked_errors == Common.none &&
          @traffic_control == Common.none &&
          @traffic_recovery == Common.none &&
          @error_notifier == Common.none &&
          @notifiers == Common.none &&
          @data_store == Common.none
      end

      def ==(other)
        other.is_a?(Settings) &&
          name == other.name &&
          cool_off_time == other.cool_off_time &&
          threshold == other.threshold &&
          recovery_threshold == other.recovery_threshold &&
          window_size == other.window_size &&
          skipped_errors == other.skipped_errors &&
          tracked_errors == other.tracked_errors &&
          traffic_control == other.traffic_control &&
          traffic_recovery == other.traffic_recovery &&
          error_notifier == other.error_notifier &&
          notifiers == other.notifiers &&
          data_store == other.data_store
      end

      def to_s
        effective_settings = to_h.reject { |_, v| v.empty? }
        "#<#{self.class.name} #{effective_settings.map { |(k, v)| "#{k}=#{v}" }.join(", ")}>"
      end

      def to_h
        {
          name: @name,
          cool_off_time: @cool_off_time,
          threshold: @threshold,
          recovery_threshold: @recovery_threshold,
          window_size: @window_size,
          skipped_errors: @skipped_errors,
          tracked_errors: @tracked_errors,
          traffic_control: @traffic_control,
          traffic_recovery: @traffic_recovery,
          error_notifier: @error_notifier,
          notifiers: @notifiers,
          data_store: @data_store
        }
      end
    end
  end
end
