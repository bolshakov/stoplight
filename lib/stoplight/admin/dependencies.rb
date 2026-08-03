# frozen_string_literal: true

module Stoplight
  class Admin
    class Dependencies
      def initialize(system:)
        @system = system
        @storage = @system.__stoplight__storage
      end

      def config_registry
        ConfigRegistry.new(
          registry: @system.__stoplight__registry,
          system_config: @system.config
        )
      end

      def stats_action
        Stoplight::Admin::Actions::Stats.new(
          config_registry: config_registry,
          storage: @storage,
          lights_stats: Stoplight::Admin::LightsStats
        )
      end

      def unlock_action
        Stoplight::Admin::Actions::Unlock.new(
          storage: @storage,
          config_registry: config_registry
        )
      end

      def lock_action
        Stoplight::Admin::Actions::Lock.new(
          storage: @storage,
          config_registry: config_registry
        )
      end

      def lock_all_action
        Stoplight::Admin::Actions::LockAll.new(
          storage: @storage,
          config_registry: config_registry
        )
      end

      def remove_action
        Stoplight::Admin::Actions::Remove.new(
          config_registry: config_registry,
          storage: @storage,
          registry: @system.__stoplight__registry
        )
      end
    end
  end
end
