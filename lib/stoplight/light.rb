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
    def_delegator :configuration, :data_store

    # @!attribute [r] threshold
    #   @return [Integer]
    def_delegator :configuration, :threshold

    # @!attribute [r] cool_off_time
    #   @return [Fixnum]
    def_delegator :configuration, :cool_off_time

    # @!attribute [r] window_size
    #   @return [Float]
    def_delegator :configuration, :window_size

    # @!attribute [r] notifiers
    #   # @return [Array<Notifier::Base>]
    def_delegator :configuration, :notifiers

    # @!attribute [r] error_notifier
    #   # @return [Proc]
    def_delegator :configuration, :error_notifier

    # @!attribute [r] name
    #   @return [String]
    def_delegator :configuration, :name

    # @return [Stoplight::Configuration]
    # @api private
    attr_reader :configuration

    class << self
      # @param settings [Hash]
      #   @see +Stoplight::Configuration#initialize+
      # @return [Stoplight::Light]
      def with(**settings)
        new Configuration.new(**settings)
      end
    end

    # @param configuration [Stoplight::Configuration]
    def initialize(configuration)
      @configuration = configuration
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
