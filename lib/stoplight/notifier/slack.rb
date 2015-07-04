# coding: utf-8

module Stoplight
  module Notifier
    # @see Base
    class Slack < Base
      # @return [Proc]
      attr_reader :formatter

      # @return [::Slack::Notifier]
      attr_reader :slack

      # @param slack [::Slack::Notifier]
      # @param formatter [Proc, nil]
      def initialize(slack, formatter = nil)
        @slack = slack
        @formatter = formatter || Default::FORMATTER
      end

      def notify(light, from_color, to_color, error)
        message = formatter.call(light, from_color, to_color, error)
        slack.ping(message)
        message
      end
    end
  end
end
