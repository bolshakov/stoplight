# coding: utf-8

module Stoplight
  module Notifier
    class Base
      def notify(_message)
        fail NotImplementedError
      end
    end
  end
end
