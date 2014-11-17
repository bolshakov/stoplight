# coding: utf-8

module Stoplight
  module Notifier
    class Base
      def notify(_light, _from_color, _to_color, _error)
        fail NotImplementedError
      end
    end
  end
end
