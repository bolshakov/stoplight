# frozen_string_literal: true

module Stoplight
  class Admin
    class LightsRepository
      def initialize(registry:, storage:, system_config:)
        @storage = storage
        @registry = registry
        @system_config = system_config
      end

      def all
        @registry
          .ids
          .filter_map { |id| load_light_view(id) }
          .sort_by(&:default_sort_key)
      end

      def with_color(*colors)
        requested_colors = Array(colors)

        all.select do |light|
          requested_colors.include?(light.color)
        end
      end

      # @param name locks light by its name
      # @param color locks to this color. When nil is given, locks to the current color
      def lock(name, color = nil)
        config = build_config(name)
        return unless config
        color ||= @storage.state_snapshot(config).color
        @storage.lock(config, color)
      end

      # @param id unlocks light by its name
      def unlock(id)
        config = build_config(id)
        @storage.unlock(config) if config
      end

      # @param id removes light metadata by its name
      def remove(id)
        config = build_config(id)
        @storage.delete(config) if config
        @registry.unregister(id)  # TODO: move to @storage?
      end

      private def load_light_view(id)
        config = build_config(id)
        return unless config

        # failures, state
        state_snapshot = @storage.state_snapshot(config)
        metrics = @storage.metrics_snapshot(config)

        Light.new(
          id: config.id,
          name: config.name,
          color: state_snapshot.color,
          state: state_snapshot.locked_state,
          failures: [metrics.last_error].compact,
          failure_count: metrics.consecutive_errors
        )
      end

      private def build_config(id)
        config = @registry.config_for(id)
        return if config.nil?

        overrides = config.slice("name", "cool_off_time", "window_size").compact.transform_keys(&:to_sym)
        @system_config.with(id:, **overrides)
      end
    end
  end
end
