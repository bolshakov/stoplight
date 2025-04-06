# frozen_string_literal: true

module Stoplight
  #
  # @api private use +Stoplight()+ method instead
  class Light
    extend Forwardable
    include CircuitBreaker
    include Lockable
    include Runnable

    # @!attribute [r] data_store
    #   @return [Stoplight::DataStore::Base]
    def_delegator :config, :data_store

    # @!attribute [r] threshold
    #   @return [Integer]
    def_delegator :config, :threshold

    # @!attribute [r] cool_off_time
    #   @return [Fixnum]
    def_delegator :config, :cool_off_time

    # @!attribute [r] window_size
    #   @return [Float]
    def_delegator :config, :window_size

    # @!attribute [r] notifiers
    #   # @return [Array<Notifier::Base>]
    def_delegator :config, :notifiers

    # @!attribute [r] error_notifier
    #   # @return [Proc]
    def_delegator :config, :error_notifier

    # @!attribute [r] name
    #   @return [String]
    def_delegator :config, :name

    # @return [Stoplight::Config]
    # @api private
    attr_reader :config

    class << self
      # @param settings [Hash]
      #   @see +Stoplight::Configuration#initialize+
      # @return [Stoplight::Light]
      def with(**settings)
        new Config.new(**settings)
      end
    end

    # @param config [Stoplight::Config]
    def initialize(config)
      @config = config
    end

    # @param other [any]
    # @return [Boolean]
    def ==(other)
      other.is_a?(self.class) && config == other.config
    end

    private

    def reconfigure(config)
      self.class.new(config)
    end
  end
end
