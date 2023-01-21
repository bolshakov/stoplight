# frozen_string_literal: true

module Stoplight
  class Light
    # @api private
    module Deprecated
      def default_data_store
        warn '[DEPRECATED] `Stoplight::Light.default_data_store` is deprecated. ' \
          'Please use `Stoplight.default_data_store` instead.'
        Stoplight.default_data_store
      end

      def default_data_store=(value)
        warn '[DEPRECATED] `Stoplight::Light.default_data_store=` is deprecated. ' \
          'Please use `Stoplight.default_data_store=` instead.'
        Stoplight.default_data_store = value
      end

      def default_notifiers
        warn '[DEPRECATED] `Stoplight::Light.default_notifiers` is deprecated. ' \
          'Please use `Stoplight.default_notifiers` instead.'
        Stoplight.default_notifiers
      end

      def default_notifiers=(value)
        warn '[DEPRECATED] `Stoplight::Light.default_notifiers=` is deprecated. ' \
          'Please use `Stoplight.default_notifiers=` instead.'
        Stoplight.default_notifiers = value
      end

      def default_error_notifier
        warn '[DEPRECATED] `Stoplight::Light.default_error_notifier` is deprecated. ' \
          'Please use `Stoplight.default_error_notifier` instead.'
        Stoplight.default_error_notifier
      end

      def default_error_notifier=(value)
        warn '[DEPRECATED] `Stoplight::Light.default_error_notifier=` is deprecated. ' \
          'Please use `Stoplight.default_error_notifier=` instead.'
        Stoplight.default_error_notifier = value
      end
    end
  end
end
