# frozen_string_literal: true

module Stoplight
  class Admin
    module Actions
      class Stats < Action
        # @!attribute lights_stats
        #   @return [Class<Stoplight::Admin::LightsStats>]
        attr_reader :lights_stats
        private :lights_stats

        # @param lights_stats [Class<Stoplight::Admin::LightsStats>]
        def initialize(lights_stats:, **deps)
          super(**deps)
          @lights_stats = lights_stats
        end

        # @return [(Stoplight::Admin::LightsRepository::Light)]
        def call(*)
          lights = lights_repository.all
          stats = lights_stats.call(lights)
          [lights, stats]
        end
      end
    end
  end
end
