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

    # @return [String]
    attr_reader :name
    # @return [Proc]
    attr_reader :error_handler
    # @return [Stoplight::Configuration]
    # @api private
    attr_reader :configuration

    # @param name [String]
    # @param configuration [Stoplight::Configuration]
    # @yield []
    def initialize(name, configuration)
      @configuration = configuration
      @name = name
      @error_handler = Default::ERROR_HANDLER
    end

    # @yieldparam error [Exception]
    # @yieldparam handle [Proc]
    # @return [Stoplight::CircuitBreaker]
    def with_error_handler(&error_handler)
      @error_handler = error_handler
      self
    end

    private

    def reconfigure(configuration)
      @configuration = configuration
      self
    end
  end
end
