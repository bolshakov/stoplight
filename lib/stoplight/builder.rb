# frozen_string_literal: true

require 'forwardable'

module Stoplight
  # An interface to build Stoplight configuration. The builder is
  # immutable, so it's safe to pass an instance of this builder
  # across the code.
  #
  # @example
  #   circuit_breaker = Stoplight('http_api')
  #     .with_data_store(data_store)
  #     .with_cool_off_time(60)
  #     .with_threshold(5)
  #     .with_window_size(3600)
  #     .with_notifiers(notifiers)
  #     .with_error_notifier(error_notifier) #=> <#Stoplight::Builder ..>
  #
  # It's safe to pass this +circuit_breaker+ around your code like this:
  #
  #     def call(circuit_breaker)
  #       circuit_breaker.run { call_api }
  #     end
  #
  # @api private use +Stoplight()+ method instead
  class Builder
    include CircuitBreaker
    extend Forwardable

    def_delegator :build, :color
    def_delegator :build, :name
    def_delegator :build, :state
    def_delegator :build, :run
    def_delegator :build, :lock
    def_delegator :build, :unlock

    class << self
      # @param settings [Hash]
      #   @see +Stoplight::Configuration#initialize+
      # @return [Stoplight::Builder]
      def with(**settings)
        new Configuration.new(**settings)
      end
    end

    # @param [Stoplight::Configuration]
    def initialize(configuration)
      @configuration = configuration
    end

    # @return [Stoplight::Light]
    def build
      Light.new(configuration.name, configuration)
    end

    # @param other [any]
    # @return [Boolean]
    def ==(other)
      other.is_a?(self.class) && configuration == other.configuration
    end

    private

    def reconfigure(configuration)
      self.class.new(configuration)
    end
  end
end
