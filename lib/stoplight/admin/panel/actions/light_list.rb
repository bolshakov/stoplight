# frozen_string_literal: true

module Stoplight
  class Admin
    class Panel
      module Actions
        class LightList
          COLORS = [
            Stoplight::Color::GREEN,
            Stoplight::Color::YELLOW,
            Stoplight::Color::RED
          ].freeze

          def initialize(config_registry:, storage:)
            @config_registry = config_registry
            @storage = storage
          end

          def call
            @config_registry.all.map { |config| build_light(config) }.sort_by { |light| sort_key(light) }
          end

          private def build_light(config)
            LightSummary.new(
              id: config.id,
              name: config.name,
              color: @storage.state_snapshot(config).color
            )
          end

          private def sort_key(light)
            [-COLORS.index(light.color).to_i, light.name]
          end
        end
      end
    end
  end
end
