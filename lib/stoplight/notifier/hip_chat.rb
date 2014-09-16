# coding: utf-8

module Stoplight
  module Notifier
    # @note hipchat ~> 1.3.0
    class HipChat < Base
      DEFAULT_FORMAT = '@all Switching %s from %s to %s'
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

      def notify(light, from_color, to_color)
        message = format(@format, light.name, from_color, to_color)
        @client[@room].send('Stoplight', message, @options)
      end
    end
  end
end
