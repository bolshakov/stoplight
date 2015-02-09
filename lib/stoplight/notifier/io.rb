# coding: utf-8

require 'stringio'

module Stoplight
  module Notifier
    # @see Base
    class IO < Base
      # @return [Proc]
      attr_reader :formatter
      # @return [::IO]
      attr_reader :io

      # @param io [::IO]
      # @param formatter [Proc, nil]
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
