# frozen_string_literal: true

module Stoplight
  module Notifier
    module Generic # rubocop:disable Style/Documentation
      # @return [Proc]
      attr_reader :formatter

      DEFAULT_FORMATTER = lambda do |config, from_color, to_color, error|
        words = ["Switching", config.name, "from", from_color, "to", to_color]
        words += ["because", error.class, error.message] if error
        words.join(" ")
      end

      # @param object [Object]
      # @param formatter [Proc, nil]
      def initialize(object, formatter = nil)
        @object = object
        @formatter = formatter || DEFAULT_FORMATTER
      end

      # @see Base#notify
      def notify(light, from_color, to_color, error)
        message = formatter.call(light.config, from_color, to_color, error)
        put(message)
        message
      end

      private

      def put(_message)
        raise NotImplementedError
      end
    end
  end
end
