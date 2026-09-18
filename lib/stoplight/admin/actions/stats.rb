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
          LightView.new(
            config:,
            metrics_snapshot: @storage.metrics_snapshot(config),
            state_snapshot: @storage.state_snapshot(config),
            recovery_metrics_snapshot: @storage.recovery_metrics_snapshot(config)
          )
        end
      end
    end
  end
end
