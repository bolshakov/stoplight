# coding: utf-8

module Stoplight
  module Notifier
    class HipChat < Base
      DEFAULT_OPTIONS = {
        color: 'purple',
        message_format: 'text',
        notify: true
      }.freeze

      attr_reader :formatter
      attr_reader :hip_chat
      attr_reader :options
      attr_reader :room

      def initialize(hip_chat, room, formatter = nil, options = {})
        @hip_chat = hip_chat
        @room = room
        @formatter = formatter || Default::FORMATTER
        @options = DEFAULT_OPTIONS.merge(options)
      end

      def notify(light, from_color, to_color, error)
        message = formatter.call(light, from_color, to_color, error)
        hip_chat[room].send('Stoplight', message, options)
        message
      end
    end
  end
end
