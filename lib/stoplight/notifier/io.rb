# coding: utf-8

module Stoplight
  module Notifier
    class IO < Base
      DEFAULT_FORMATTER = lambda do |light, from_color, to_color, failure|
        words = ['Switching', light.name, 'from', from_color, 'to', to_color]

        if failure
          words += ['because', failure.error_class, failure.error_message]
        end

        words.join(' ')
      end

      # @param io [IO]
      # @param formatter [Proc, nil]
      def initialize(io, formatter = nil)
        @io = io
        @formatter = formatter || DEFAULT_FORMATTER
      end

      def notify(light, from_color, to_color, failure)
        message = @formatter.call(light, from_color, to_color, failure)
        @io.puts(message)
      end
    end
  end
end
