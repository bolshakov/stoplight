# frozen_string_literal: true

module Stoplight
  class Admin
    module Actions
      # This action locks all lights green
      class LockAll < Action
        def initialize(config_registry:, storage:)
          @config_registry = config_registry
          @storage = storage
        end

        def call(color:)
          @config_registry.all.each do |config|
            current_color = @storage.state_snapshot(config).color
            if [Color::RED, Color::YELLOW].include?(current_color)
              @storage.lock(config, color)
            end
          end
        end
      end
    end
  end
end
