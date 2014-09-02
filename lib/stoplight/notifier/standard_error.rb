# coding: utf-8

module Stoplight
  module Notifier
    class StandardError < Base
      DEFAULT_FORMAT = '%s'

      def initialize(format = nil)
        @format = format || DEFAULT_FORMAT
      end

      def notify(message)
        warn(@format % message)
      end
    end
  end
end
