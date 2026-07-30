# frozen_string_literal: true

module Stoplight
  class Admin
    class Dependencies
      def initialize(system:)
        @system = system
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
        Stoplight::Admin::Actions::Unlock.new(lights_repository: lights_repository)
      end

      def green_action
        Stoplight::Admin::Actions::LockGreen.new(lights_repository: lights_repository)
      end

      def red_action
        Stoplight::Admin::Actions::LockRed.new(lights_repository: lights_repository)
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
