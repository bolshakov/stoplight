# frozen_string_literal: true

module Stoplight
  class Admin
    class ConfigRegistry
      def initialize(registry:, system_config:)
        @registry = registry
        @system_config = system_config
      end

      def find_by_id(id)
        config = @registry.config_for(id)
        return if config.nil?

        overrides = config.slice(
          "id",
          "name",
          "cool_off_time",
          "threshold",
          "recovery_threshold",
          "window_size"
        ).compact.transform_keys(&:to_sym)

        @system_config.with(id:, **overrides)
      end
    end
  end
end
