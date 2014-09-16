# coding: utf-8

module Stoplight
  module Notifier
    class Base
      # @param _light [Light]
      # @param _from_color [String]
      # @param _to_color [String]
      def notify(_light, _from_color, _to_color)
        fail NotImplementedError
      end
    end
  end
end
