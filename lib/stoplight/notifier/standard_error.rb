# coding: utf-8

module Stoplight
  module Notifier
    class StandardError < Base
      DEFAULT_FORMAT = 'Switching %s from %s to %s'

      def initialize(format = nil)
        @format = format || DEFAULT_FORMAT
      end

      def notify(light, from_color, to_color)
        warn(format(@format, light.name, from_color, to_color))
      end
    end
  end
end
