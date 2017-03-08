# coding: utf-8

module Stoplight
  module Notifier
    # @see Base
    class DataDogServiceCheck < Base
      DEFAULT_OPTIONS = {
        timestamp: Time.now,
        tags: {}
      }.freeze

      # @return [Proc]
      attr_reader :formatter
      # @return [::Dogapi::Client]
      attr_reader :dogapi
      # @return[Hash{Symbol => Object}]
      attr_reader :options
      # @return [String]
      attr_reader :prefix
      # @return [String]
      attr_reader :host

      # @param dogapi [::Dogapi::Client]
      # @param prefix [String]
      # @param host [String]
      # @param formatter [Proc, nil]
      # @param options [Hash{Symbol => Object}]
      # @option options [Time] :timestamp
      # @option options [Hash] :tags
      def initialize(dogapi, host, prefix, formatter = nil, options = {})
        @dogapi = dogapi
        @host = host
        @prefix = prefix
        @formatter = formatter || Default::FORMATTER
        @options = DEFAULT_OPTIONS.merge(options)
      end

      def notify(light, from_color, to_color, error)
        message = formatter.call(light, from_color, to_color, error)
        opts = options.merge(
          message: message,
          timestamp: options[:timestamp].to_i
        )
        dogapi.service_check(check(light), host, get_status(light.color), opts)
        message
      end

      def check(light)
        prefix.gsub(/\.$/, '') + '.' + light.name
      end

      def get_status(color)
        case color
        when Color::GREEN then 0
        when Color::RED then 2
        else 1
        end
      end
    end
  end
end
