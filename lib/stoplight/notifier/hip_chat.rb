# coding: utf-8

module Stoplight
  module Notifier
    # @note hipchat ~> 1.3.0
    class HipChat < Base
      DEFAULT_FORMAT = '@all %s'
      DEFAULT_OPTIONS = { color: 'red', message_format: 'text', notify: true }

      # @param client [HipChat::Client]
      # @param room [String]
      # @param options [Hash]
      def initialize(client, room, format = nil, options = {})
        @client = client
        @room = room
        @format = format || DEFAULT_FORMAT
        @options = DEFAULT_OPTIONS.merge(options)
      end

      def notify(message)
        @client[@room].send('Stoplight', @format % message, @options)
      end
    end
  end
end
