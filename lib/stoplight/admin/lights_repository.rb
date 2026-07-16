# frozen_string_literal: true

module Stoplight
  class Admin
    class LightsRepository
      def initialize(registry:, storage:, system_config:)
        @storage = storage
        @registry = registry
        @system_config = system_config
      end

      # @return [<Stoplight::Admin::LightsRepository::Light>]
      def all
        @registry
          .names
          .map { |name| load_light_view(name) }
          .sort_by(&:default_sort_key)
      end

      # @param colors <String>] colors name
      # @return [<Stoplight::Admin::LightsRepository::Light>] lights with the requested colors
      #
      def with_color(*colors)
        requested_colors = Array(colors)

        all.select do |light|
          requested_colors.include?(light.color)
        end
      end

      # @param name [String] locks light by its name
      # @param color [String, nil] locks to this color. When nil is given, locks to the current
      #   color
      # @return [void]
      def lock(name, color = nil)
        config = build_config(name)
        color ||= @storage.state_snapshot(config).color
        @storage.lock(config, color)
      end

      # @param name [String] unlocks light by its name
      # @return [void]
      def unlock(name)
        @storage.unlock(build_config(name))
      end

      # @param name [String] removes light metadata by its name
      # @return [void]
      def remove(name)
        config = @system_config.with(name:)
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
        @system_config.with(name:)
      end
    end
  end
end
