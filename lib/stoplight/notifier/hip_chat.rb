# coding: utf-8

module Stoplight
  module Notifier
    # @note hipchat ~> 1.3.0
    class HipChat < Base
      DEFAULT_OPTIONS = { color: 'red', message_format: 'text', notify: true }

      # @param client [HipChat::Client]
      # @param room [String]
      # @param options [Hash]
      def initialize(client, room, options = {})
        @client = client
        @room = room
        @options = DEFAULT_OPTIONS.merge(options)
      end

      def notify(message)
        @client[@room].send('Stoplight', "@all #{message}", @options)
      end
    end
  end
end
