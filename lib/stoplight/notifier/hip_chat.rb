# coding: utf-8

module Stoplight
  module Notifier
    # @note hipchat ~> 1.3.0
    class HipChat < Base
      DEFAULT_FORMATTER = lambda do |light, from_color, to_color, failure|
        words = [
          '@all', 'Switching', light.name, 'from', from_color, 'to', to_color
        ]

        if failure
          words += ['because', failure.error_class, failure.error_message]
        end

        words.join(' ')
      end
      DEFAULT_OPTIONS = { color: 'red', message_format: 'text', notify: true }

      # @param client [HipChat::Client]
      # @param room [String]
      # @param formatter [Proc, nil]
      # @param options [Hash]
      def initialize(client, room, formatter = nil, options = {})
        @client = client
        @room = room
        @formatter = formatter || DEFAULT_FORMATTER
        @options = DEFAULT_OPTIONS.merge(options)
      end

      def notify(light, from_color, to_color, failure)
        message = @formatter.call(light, from_color, to_color, failure)
        @client[@room].send('Stoplight', message, @options)
      rescue *errors => error
        raise Error::BadNotifier, error
      end

      private

      def errors
        [
          ::HipChat::InvalidApiVersion,
          ::HipChat::RoomMissingOwnerUserId,
          ::HipChat::RoomNameTooLong,
          ::HipChat::Unauthorized,
          ::HipChat::UnknownResponseCode,
          ::HipChat::UnknownRoom,
          ::HipChat::UnknownUser,
          ::HipChat::UsernameTooLong
        ]
      end
    end
  end
end
