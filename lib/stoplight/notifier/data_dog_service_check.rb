# coding: utf-8

module Stoplight
  module Notifier
    # @see Base
    class DataDogServiceCheck < Base
      DEFAULT_OPTIONS = {
        timestamp: Time.now,
        tags: {}
      }.freeze

      # @return [String]
      attr_reader :api_key
      # @return [Proc]
      attr_reader :formatter
      # @return[Hash{Symbol => Object}]
      attr_reader :options
      # @return [Object]
      attr_reader :dog
      # @return [String]
      attr_reader :prefix
      # @return [String]
      attr_reader :host

      # @param api_key [String]
      # @param check [String]
      # @param host_name [String]
      # @param formatter [Proc, nil]
      # @param options [Hash{Symbol => Object}]
      # @option options [Time] :timestamp
      # @option options [Hash] :tags
      def initialize(api_key, host, prefix, formatter = nil, options = nil)
        @api_key = api_key
        @prefix = prefix
        @host = host
        @formatter = formatter || Default::FORMATTER
        @options = DEFAULT_OPTIONS.merge(options)
        @dog = Dogapi::Client.new(api_key)
      end

      def notify(light, from_color, to_color, error)
        message = formatter.call(light, from_color, to_color, error)
        opts = options.merge(
          message: message,
          timestamp: options[:timestamp].to_i
        )
        dog.service_check(check(light), host, get_status(light.color), opts)
      end

      def check(light)
        prefix.gsub(/\.$/, '') + '.' + light.name
      end

      def get_status(color)
        case color
        when Color::GREEN then 0
        when Color::YELLOW then 1
        when Color::RED then 2
        else 3
        end
      end
    end
  end
end
