# frozen_string_literal: true

module Stoplight
  class Admin
    module Actions
      # This action locks every red/yellow light green - a bulk recovery action, never a bulk
      # lockout, so it accepts no other color.
      class LockAll < Action
        def initialize(config_registry:, storage:)
          @config_registry = config_registry
          @storage = storage
        end

        def call(color:)
          halt 400 unless color == Color::GREEN

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
