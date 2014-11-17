# coding: utf-8

require 'stringio'

module Stoplight
  module Notifier
    class IO < Base
      attr_reader :formatter
      attr_reader :io

      def initialize(io, formatter = nil)
        @io = io
        @formatter = formatter || Default::FORMATTER
      end

      def notify(light, from_color, to_color, error)
        message = formatter.call(light, from_color, to_color, error)
        io.puts(message)
        message
      end
    end
  end
end
