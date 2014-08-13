# coding: utf-8

module Stoplight
  module Notifier
    class StandardError < Base
      def notify(message)
        warn(message)
      end
    end
  end
end
