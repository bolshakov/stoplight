# frozen_string_literal: true

module Stoplight
  class Admin
    class Dependencies
      # @!attribute data_store
      #   @return [Stoplight::DataStore::Base]
      attr_reader :data_store
      private :data_store

      # @param data_store [Stoplight::DataStore::Base]
      def initialize(data_store:)
        @data_store = data_store
      end

      # @return [Stoplight::Admin::LightsRepository]
      def lights_repository
        Stoplight::Admin::LightsRepository.new(data_store: data_store)
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
    end
  end
end
