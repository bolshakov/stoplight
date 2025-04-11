# frozen_string_literal: true

module Stoplight
  class Light < CircuitBreaker
    # A +Stoplight::Light+ configuration object.
    class Config < BaseConfig
      schema schema.strict
      transform_keys(&:to_sym)

      DEFAULT_COOL_OFF_TIME = 60.0
      DEFAULT_THRESHOLD = 3
      DEFAULT_WINDOW_SIZE = Float::INFINITY
      DEFAULT_SKIPPED_ERRORS = [].freeze
      DEFAULT_TRACKED_ERRORS = [StandardError].freeze
      DEFAULT_DATA_STORE = DataStore::Memory.new
      DEFAULT_NOTIFIERS = [
        Notifier::IO.new($stderr)
      ].freeze
      DEFAULT_ERROR_NOTIFIER = ->(error) { warn error }

      DEFAULT_SETTINGS = {
        cool_off_time: DEFAULT_COOL_OFF_TIME,
        threshold: DEFAULT_THRESHOLD,
        window_size: DEFAULT_WINDOW_SIZE,
        tracked_errors: DEFAULT_TRACKED_ERRORS,
        skipped_errors: DEFAULT_SKIPPED_ERRORS,
        data_store: DEFAULT_DATA_STORE,
        error_notifier: DEFAULT_ERROR_NOTIFIER,
        notifiers: DEFAULT_NOTIFIERS
      }.freeze

      attribute :name, Types::Coercible::String

      class << self
        alias_method :__new_without_defaults__, :new

        # It overrides the +Config.new+ to inject library-level default settings
        # @api private this method should not be used directly
        # @see +Stoplight()+
        def new(**settings)
          __new_without_defaults__(**default_settings.merge(settings))
        end

        private def default_settings
          DEFAULT_SETTINGS
        end
      end

      # Updates the configuration with new settings and returns a new instance.
      #
      # @return [Stoplight::Light::Config]
      def with(**settings)
        self.class.new(**to_h.merge(settings))
      end
    end
  end
end
