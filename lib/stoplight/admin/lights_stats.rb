# frozen_string_literal: true

module Stoplight
  module Admin
    class LightsStats
      EMPTY_STATS = {
        count_red: 0, count_yellow: 0, count_green: 0,
        percent_red: 0, percent_yellow: 0, percent_green: 0
      }.freeze

      # @!attribute lights
      #   @return [<Stoplight::Admin::LightsRepository::Light>]
      attr_reader :lights
      private :lights

      class << self
        def call(lights)
          new(lights).call
        end
      end

      # @param lights [<Stoplight::Admin::LightsRepository::Light>]
      def initialize(lights)
        @lights = lights
      end

      def call
        return EMPTY_STATS if size.zero?

        EMPTY_STATS.merge(
          count_red: count_red,
          count_yellow: count_yellow,
          count_green: count_green,
          percent_red: percent_red,
          percent_yellow: percent_yellow,
          percent_green: percent_green
        )
      end

      private def count_red
        count_lights(RED)
      end

      private def percent_red
        percent_lights(RED)
      end

      private def count_green
        count_lights(GREEN)
      end

      private def percent_green
        percent_lights(GREEN)
      end

      private def count_yellow
        count_lights(YELLOW)
      end

      private def percent_yellow
        percent_lights(YELLOW)
      end

      private def count_lights(color)
        lights.count { |l| l.color == color }
      end

      private def percent_lights(color)
        (100 * count_lights(color).fdiv(size)).ceil
      end

      private def size
        lights.size
      end
    end
  end
end
