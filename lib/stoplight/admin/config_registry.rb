# frozen_string_literal: true

module Stoplight
  class Admin
    class ConfigRegistry
      def initialize(registry:, system_config:)
        @registry = registry
        @system_config = system_config
      end

      def all
        @registry.all_configs.map do |config|
          deserialize_config(config)
        end
      end

      def find_by_id(id)
        config = @registry.config_for(id)
        return if config.nil?

        deserialize_config(config)
      end

      private

      def deserialize_config(config)
        overrides = config.slice(
          "id",
          "name",
          "cool_off_time",
          "threshold",
          "recovery_threshold",
          "window_size"
        ).compact.transform_keys(&:to_sym)

        @system_config.with(**overrides)
      end
    end
  end
end
