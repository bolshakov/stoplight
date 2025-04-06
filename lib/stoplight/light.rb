# frozen_string_literal: true

module Stoplight
  #
  # @api private use +Stoplight()+ method instead
  class Light < CircuitBreaker
    include Configurable
    include Lockable
    include Runnable

    class << self
      # @param settings [Hash]
      #   @see +Stoplight::Config#initialize+
      # @return [Stoplight::Light]
      def with(**settings)
        new Config.new(**settings)
      end
    end

    # @!attribute [r] config
    #   @return [Stoplight::Config]
    #   @api private
    attr_reader :config

    # @param config [Stoplight::Config]
    def initialize(config)
      @config = config
    end

    # @param other [any]
    # @return [Boolean]
    def ==(other)
      other.is_a?(self.class) && config == other.config
    end
  end
end
