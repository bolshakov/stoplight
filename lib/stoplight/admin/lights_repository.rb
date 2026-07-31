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
          .names
          .map { |name| load_light_view(name) }
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
        color ||= @storage.state_snapshot(config).color
        @storage.lock(config, color)
      end

      # @param name unlocks light by its name
      def unlock(name)
        @storage.unlock(build_config(name))
      end

      # @param name removes light metadata by its name
      def remove(name)
        config = build_config(name)
        @storage.delete(config)
        @registry.unregister(name)
      end

      private def load_light_view(name)
        config = build_config(name)

        # failures, state
        state_snapshot = @storage.state_snapshot(config)
        metrics = @storage.metrics_snapshot(config)

        Light.new(
          name: name,
          color: state_snapshot.color,
          state: state_snapshot.locked_state,
          failures: [metrics.last_error].compact,
          failure_count: metrics.consecutive_errors
        )
      end

      private def build_config(name)
        config = @registry.config_for(name)
        return @system_config.with(name:, id: Domain::Id.for(name)) if config.nil?

        overrides = config.slice("cool_off_time", "window_size").compact.transform_keys(&:to_sym)
        @system_config.with(name:, id: Domain::Id.for(name), **overrides)
      end
    end
  end
end
