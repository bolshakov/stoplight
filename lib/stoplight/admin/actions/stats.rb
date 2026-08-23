# frozen_string_literal: true

module Stoplight
  class Admin
    module Actions
      class Stats < Action
        def initialize(lights_stats:, config_registry:, storage:)
          @lights_stats = lights_stats
          @config_registry = config_registry
          @storage = storage
        end

        def call
          lights = @config_registry.all.map { |config| build_light(config) }.sort_by(&:default_sort_key)
          stats = @lights_stats.call(lights)
          [lights, stats]
        end

        private def build_light(config)
          state_snapshot = @storage.state_snapshot(config)
          metrics = @storage.metrics_snapshot(config)
          recovery_metrics_snapshot = @storage.recovery_metrics_snapshot(config)

          LightView.new(
            id: config.id,
            config:,
            color: state_snapshot.color,
            state: state_snapshot.locked_state,
            failures: [metrics.last_error].compact,
            failure_count: metrics.consecutive_errors,
            state_snapshot:,
            recovery_metrics_snapshot:
          )
        end
      end
    end
  end
end
