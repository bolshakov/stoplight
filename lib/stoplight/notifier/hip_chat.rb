# coding: utf-8

module Stoplight
  module Notifier
    # @note hipchat ~> 1.3.0
    class HipChat < Base
      # @param client [HipChat::Client]
      # @param room [String]
      # @param options [Hash]
      def initialize(client, room, options = {})
        @client = client
        @room = room
        @options = default_options.merge(options)
      end

      def notify(message)
        @client[@room].send('Stoplight', "@all #{message}", @options)
      end

      private

      def default_options
        { color: 'red', message_format: 'text', notify: true }
      end
    end
  end
end
