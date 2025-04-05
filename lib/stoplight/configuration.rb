# frozen_string_literal: true

module Stoplight
  # A +Stoplight::Light+ configuration object.
  class Configuration
    class << self
      alias __new_without_defaults__ new

      # It overrides the +Configuration.new+ to inject default settings
      # @see +Stoplight::Configuration#initialize+
      def new(**settings)
        __new_without_defaults__(
          **default_settings.merge(settings)
        )
      end

      private

      # @return [Hash]
      def default_settings
        {
          cool_off_time: Default::COOL_OFF_TIME,
          data_store: Stoplight.default_data_store,
          error_notifier: Stoplight.default_error_notifier,
          notifiers: Stoplight.default_notifiers,
          threshold: Default::THRESHOLD,
          window_size: Default::WINDOW_SIZE
        }
      end
    end

    # @!attribute [r] name
    #   @return [String]
    attr_reader :name

    # @!attribute [r] cool_off_time
    #   @return [Numeric]
    attr_reader :cool_off_time

    # @!attribute [r] data_store
    #   @return [Stoplight::DataStore::Base]
    attr_reader :data_store

    # @!attribute [r] error_notifier
    #   # @return [StandardError => void]
    attr_reader :error_notifier

    # @!attribute [r] notifiers
    #   # @return [Array<Notifier::Base>]
    attr_reader :notifiers

    # @!attribute [r] threshold
    #   @return [Numeric]
    attr_reader :threshold

    # @!attribute [r] window_size
    #   @return [Numeric]
    attr_reader :window_size

    # @param name [String]
    # @param cool_off_time [Numeric]
    # @param data_store [Stoplight::DataStore::Base]
    # @param error_notifier [Proc]
    # @param notifiers [Stoplight::Notifier::Base]
    # @param threshold [Numeric]
    # @param window_size [Numeric]
    def initialize(name:, cool_off_time:, data_store:, error_notifier:, notifiers:, threshold:, window_size:)
      @name = name
      @cool_off_time = cool_off_time
      @data_store = data_store
      @error_notifier = error_notifier
      @notifiers = notifiers
      @threshold = threshold
      @window_size = window_size
    end

    # @param other [any]
    # @return [Boolean]
    def ==(other)
      other.is_a?(self.class) && settings == other.settings
    end

    # @param cool_off_time [Numeric]
    # @param data_store [Stoplight::DataStore::Base]
    # @param error_notifier [Proc]
    # @param name [String]
    # @param notifiers [Array<Stoplight::Notifier::Base>]
    # @param threshold [Numeric]
    # @param window_size [Numeric]
    # @return [Stoplight::Configuration]
    def with(
      cool_off_time: self.cool_off_time,
      data_store: self.data_store,
      error_notifier: self.error_notifier,
      name: self.name,
      notifiers: self.notifiers,
      threshold: self.threshold,
      window_size: self.window_size
    )
      Configuration.new(
        cool_off_time: cool_off_time,
        data_store: data_store,
        error_notifier: error_notifier,
        name: name,
        notifiers: notifiers,
        threshold: threshold,
        window_size: window_size
      )
    end

    protected

    # @return [Hash]
    def settings
      {
        cool_off_time: cool_off_time,
        data_store: data_store,
        error_notifier: error_notifier,
        name: name,
        notifiers: notifiers,
        threshold: threshold,
        window_size: window_size
      }
    end
  end
end
