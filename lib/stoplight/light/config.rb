# frozen_string_literal: true

module Stoplight
  class Light < CircuitBreaker
    # A +Stoplight::Light+ configuration object.
    class Config < BaseConfig
      schema schema.strict
      transform_keys(&:to_sym)

      DEFAULT_SETTINGS = {
        cool_off_time: Stoplight::Default::COOL_OFF_TIME,
        data_store: Stoplight.default_data_store,
        error_notifier: Stoplight.default_error_notifier,
        notifiers: Stoplight.default_notifiers,
        threshold: Stoplight::Default::THRESHOLD,
        window_size: Stoplight::Default::WINDOW_SIZE,
        tracked_errors: Stoplight::Default::TRACKED_ERRORS,
        skipped_errors: Stoplight::Default::SKIPPED_ERRORS
      }.freeze

      attribute :name, Types::Coercible::String

      class << self
        alias_method :__new_without_defaults__, :new

        # It overrides the +Config.new+ to inject library-level default settings
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
