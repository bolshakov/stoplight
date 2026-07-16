# frozen_string_literal: true

module Stoplight
  class Admin
    class Dependencies
      # @param system [Stoplight::Wiring::System]
      def initialize(system:)
        @system = system
      end

      # @return [Stoplight::Admin::LightsRepository]
      def lights_repository
        Stoplight::Admin::LightsRepository.new(
          registry: @system.__stoplight__registry,
          storage: @system.__stoplight__storage,
          system_config: @system.system_config
        )
      end

      # @return [Stoplight::Admin::Actions::Stats]
      def stats_action
        Stoplight::Admin::Actions::Stats.new(
          lights_repository: lights_repository,
          lights_stats: Stoplight::Admin::LightsStats
        )
      end

      # @return [Stoplight::Admin::Actions::Unlock]
      def unlock_action
        Stoplight::Admin::Actions::Unlock.new(lights_repository: lights_repository)
      end

      # @return [Stoplight::Admin::Actions::LockGreen]
      def green_action
        Stoplight::Admin::Actions::LockGreen.new(lights_repository: lights_repository)
      end

      # @return [Stoplight::Admin::Actions::LockRed]
      def red_action
        Stoplight::Admin::Actions::LockRed.new(lights_repository: lights_repository)
      end

      # @return [Stoplight::Admin::Actions::LockAllGreen]
      def green_all_action
        Stoplight::Admin::Actions::LockAllGreen.new(lights_repository: lights_repository)
      end

      # @return [Stoplight::Admin::Actions::Remove]
      def remove_action
        Stoplight::Admin::Actions::Remove.new(lights_repository: lights_repository)
      end
    end
  end
end
