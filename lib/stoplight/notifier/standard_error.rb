# coding: utf-8

module Stoplight
  module Notifier
    class StandardError < Base
      DEFAULT_FORMATTER = lambda do |light, from_color, to_color|
        "Switching #{light.name} from #{from_color} to #{to_color}"
      end

      # @param formatter [Proc, nil]
      def initialize(formatter = nil)
        @formatter = formatter || DEFAULT_FORMATTER
      end

      def notify(light, from_color, to_color)
        message = @formatter.call(light, from_color, to_color)
        warn(message)
      end
    end
  end
end
