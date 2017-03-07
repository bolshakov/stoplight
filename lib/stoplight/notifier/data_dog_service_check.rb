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
      attr_reader :host_name

      # @param api_key [String]
      # @param check [String]
      # @param host_name [String]
      # @param formatter [Proc, nil]
      # @param options [Hash{Symbol => Object}]
      # @option options [Time] :timestamp
      # @option options [Hash] :tags
      def initialize(api_key, host_name, prefix = '', formatter = nil, options = nil)
        @api_key = api_key
        @prefix = prefix
        @host_name = host_name
        @formatter = formatter || Default::FORMATTER
        @options = DEFAULT_OPTIONS.merge(options)
        @dog = Dogapi::Client.new(api_key)
      end

      def notify(light, from_color, to_color, error)
        @options = @options.merge({message: formatter.call(light, from_color, to_color, error)})
        if light.color == Color::GREEN
          status = 0
        elsif light.color == Color::YELLOW
          status = 1
        elsif light.color == Color::RED
          status = 2
        else
          status = 3
        end
        options[:timestamp] = options[:timestamp].to_i
        check = @prefix.empty? ? 'stoplight.' + light.name : prefix + '.' + light.name
        dog.service_check(check, host_name, status, options)
      end
    end
  end
end
