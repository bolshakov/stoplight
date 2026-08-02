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

      def lights_repository
        Stoplight::Admin::LightsRepository.new(
          registry: @system.__stoplight__registry,
          storage: @system.__stoplight__storage,
          system_config: @system.config
        )
      end

      def stats_action
        Stoplight::Admin::Actions::Stats.new(
          lights_repository: lights_repository,
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

      def green_all_action
        Stoplight::Admin::Actions::LockAllGreen.new(lights_repository: lights_repository)
      end

      def remove_action
        Stoplight::Admin::Actions::Remove.new(lights_repository: lights_repository)
      end
    end
  end
end
