# frozen_string_literal: true

module Stoplight
  class Admin
    class Panel
      module Actions
        class LightDetail
          def initialize(config_registry:, storage:)
            @config_registry = config_registry
            @storage = storage
          end

          def call(id)
            config = @config_registry.find_by_id(id)
            return nil unless config

            state_snapshot = @storage.state_snapshot(config)
            metrics_snapshot = @storage.metrics_snapshot(config)
            recovery_metrics_snapshot = @storage.recovery_metrics_snapshot(config)

            last_error = (state_snapshot.color == Stoplight::Color::YELLOW) ? recovery_metrics_snapshot.last_error : metrics_snapshot.last_error

            Panel::LightDetail.new(
              id: config.id,
              name: config.name,
              color: state_snapshot.color,
              lock_state: state_snapshot.locked_state,
              last_error: last_error,
              recovery_scheduled_after: state_snapshot.recovery_scheduled_after,
              consecutive_successes: recovery_metrics_snapshot.consecutive_successes,
              recovery_threshold: config.recovery_threshold
            )
          end
        end
      end
    end
  end
end
