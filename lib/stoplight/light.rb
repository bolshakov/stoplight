# frozen_string_literal: true

module Stoplight
  #
  # @api private use +Stoplight()+ method instead
  class Light
    include Configurable
    include Lockable
    include Runnable

    # @!attribute [r] config
    #   @return [Stoplight::Light::Config]
    #   @api private
    attr_reader :config

    # @param config [Stoplight::Light::Config]
    def initialize(config, green_run_strategy: nil, yellow_run_strategy: nil, red_run_strategy: nil)
      @config = config
      @green_run_strategy = green_run_strategy
      @yellow_run_strategy = yellow_run_strategy
      @red_run_strategy = red_run_strategy
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
