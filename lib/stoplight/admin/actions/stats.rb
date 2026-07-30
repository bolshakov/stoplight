# frozen_string_literal: true

module Stoplight
  class Admin
    module Actions
      class Stats < Action
        def initialize(lights_stats:, lights_repository:)
          super(lights_repository:)
          @lights_stats = lights_stats
        end

        def call(*)
          lights = @lights_repository.all
          stats = @lights_stats.call(lights)
          [lights, stats]
        end
      end
    end
  end
end
