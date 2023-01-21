# frozen_string_literal: true

require 'stoplight/light/deprecated'

module Stoplight
  #
  # @api private use +Stoplight()+ method instead
  class Light
    extend Forwardable
    extend Deprecated
    include Lockable
    include Runnable
    include Configurable

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
    attr_reader :code
    # @return [Proc]
    attr_reader :error_handler
    # @return [Proc, nil]
    attr_reader :fallback
    # @return [Stoplight::Configuration]
    # @api private
    attr_reader :configuration

    class << self
      alias __new_with_configuration__ new

      # It overrides the +Light.new+ method to support an old and a new
      # way of instantiation.
      #
      # @overload new(name, &code)
      #   @param name [String]
      #   @return [Stoplight::Light]
      #
      # @overload new(name, configuration)
      #   @param name [String]
      #   @param configuration [Stoplight::Configuration]
      #   @return [Stoplight::Light]
      #
      def new(name, configuration = nil, &code)
        if configuration
          __new_with_configuration__(name, configuration, &code)
        else
          warn '[DEPRECATED] Instantiating `Stoplight::Light` is deprecated. ' \
            'Please use `Stoplight()` method instead.'
          Builder.with(name: name).build(&code)
        end
      end
    end

    # @param name [String]
    # @param configuration [Stoplight::Configuration]
    # @yield []
    def initialize(name, configuration, &code)
      @configuration = configuration
      @name = name
      @code = code
      @error_handler = Default::ERROR_HANDLER
      @fallback = Default::FALLBACK
    end

    # @yieldparam error [Exception]
    # @yieldparam handle [Proc]
    # @return [self]
    def with_error_handler(&error_handler)
      @error_handler = error_handler
      self
    end

    # @yieldparam error [Exception, nil]
    # @return [self]
    def with_fallback(&fallback)
      @fallback = fallback
      self
    end

    private

    def reconfigure(configuration)
      @configuration = configuration
      self
    end
  end
end
