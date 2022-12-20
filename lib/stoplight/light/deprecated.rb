# frozen_string_literal: true

module Stoplight
  class Light
    # @api private
    module Deprecated
      def default_data_store
        warn '[DEPRECATED] `Stoplight::Light.default_data_store` is deprecated. ' \
          'Please use `Stoplight::Configuration.default_data_store` instead.'
        Configuration.default_data_store
      end

      def default_data_store=(value)
        warn '[DEPRECATED] `Stoplight::Light.default_data_store=` is deprecated. ' \
          'Please use `Stoplight::Configuration.default_data_store=` instead.'
        Configuration.default_data_store = value
      end

      def default_notifiers
        warn '[DEPRECATED] `Stoplight::Light.default_notifiers` is deprecated. ' \
          'Please use `Stoplight::Configuration.default_notifiers` instead.'
        Configuration.default_notifiers
      end

      def default_notifiers=(value)
        warn '[DEPRECATED] `Stoplight::Light.default_notifiers=` is deprecated. ' \
          'Please use `Stoplight::Configuration.default_notifiers=` instead.'
        Configuration.default_notifiers = value
      end
    end
  end
end
