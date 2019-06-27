# coding: utf-8

module Stoplight
  module Notifier
    # @see Base
    class Rollbar < Base
      DEFAULT_OPTIONS = {
        severity: 'info'
      }.freeze

      StoplightStatusChange = Class.new(Error::Base)

      # @return [Proc]
      attr_reader :formatter
      # @return [::Rollbar]
      attr_reader :rollbar
      # @return [Hash{Symbol => Object}]
      attr_reader :options

      # @param rollbar [::Rollbar]
      # @param formatter [Proc, nil]
      # @param options [Hash{Symbol => Object}]
      # @option options [String] :severity
      def initialize(rollbar, formatter = nil, options = {})
        @rollbar = rollbar
        @formatter = formatter || Default::FORMATTER
        @options = DEFAULT_OPTIONS.merge(options)
      end

      def notify(light, from_color, to_color, error)
        formatter.call(light, from_color, to_color, error).tap do |message|
          severity = options.fetch(:severity)
          exception = StoplightStatusChange.new(message)
          rollbar.__send__(severity, exception)
        end
      end
    end
  end
end
