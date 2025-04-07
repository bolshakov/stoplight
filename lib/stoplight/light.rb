# frozen_string_literal: true

module Stoplight
  #
  # @api private use +Stoplight()+ method instead
  class Light < CircuitBreaker
    include Configurable
    include Lockable
    include Runnable

    # @!attribute [r] config
    #   @return [Stoplight::Light::Config]
    #   @api private
    attr_reader :config

    # @param config [Stoplight::Light::Config]
    def initialize(config)
      @config = config
    end

    # Two lights considered equal if they have the same configuration.
    #
    # @param other [any]
    # @return [Boolean]
    def ==(other)
      other.is_a?(self.class) && config == other.config
    end
  end
end
