# frozen_string_literal: true

require 'stoplight/light/deprecated'

module Stoplight
  class Light # rubocop:disable Style/Documentation
    extend Forwardable
    extend Deprecated
    include Lockable
    include Runnable

    # @!attribute data_store
    #   @return [Stoplight::DataStore::Base]
    def_delegator :configuration, :data_store

    # @!attribute threshold
    #   @return [Integer]
    def_delegator :configuration, :threshold

    # @!attribute cool_off_time
    #   @return [Fixnum]
    def_delegator :configuration, :cool_off_time

    # @!attribute window_size
    #   @return [Float]
    def_delegator :configuration, :window_size

    # @!attribute notifiers
    #   # @return [Array<Notifier::Base>]
    def_delegator :configuration, :notifiers

    class << self
      # @return [Proc]
      attr_accessor :default_error_notifier
    end

    @default_error_notifier = Default::ERROR_NOTIFIER

    # @return [String]
    attr_reader :name
    # @return [Proc]
    attr_reader :code
    # @return [Proc]
    attr_reader :error_handler
    # @return [Proc, nil]
    attr_reader :fallback
    # @return [Proc]
    attr_reader :error_notifier
    # @return [Stoplight::Configuration]
    # @api private
    attr_reader :configuration

    # @param configuration [Stoplight::Configuration]
    # @yield []
    def initialize(name, configuration = Configuration.new(name: name), &code)
      @configuration = configuration
      @name = name
      @code = code
      @error_handler = Default::ERROR_HANDLER
      @fallback = Default::FALLBACK
      @error_notifier = self.class.default_error_notifier
    end

    # @param cool_off_time [Float]
    # @return [self]
    def with_cool_off_time(cool_off_time)
      @configuration = configuration.with_cool_off_time(cool_off_time)
      self
    end

    # @param data_store [DataStore::Base]
    # @return [self]
    def with_data_store(data_store)
      @configuration = configuration.with_data_store(data_store)
      self
    end

    # @yieldparam error [Exception]
    # @yieldparam handle [Proc]
    # @return [self]
    def with_error_handler(&error_handler)
      @error_handler = error_handler
      self
    end

    # @yieldparam error [Exception]
    # @return [self]
    def with_error_notifier(&error_notifier)
      @error_notifier = error_notifier
      self
    end

    # @yieldparam error [Exception, nil]
    # @return [self]
    def with_fallback(&fallback)
      @fallback = fallback
      self
    end

    # @param notifiers [Array<Notifier::Base>]
    # @return [self]
    def with_notifiers(notifiers)
      @configuration = configuration.with_notifiers(notifiers)
      self
    end

    # @param threshold [Fixnum]
    # @return [self]
    def with_threshold(threshold)
      @configuration = configuration.with_threshold(threshold)
      self
    end

    # @param window_size [Integer]
    # @return [self]
    def with_window_size(window_size)
      @configuration = configuration.with_window_size(window_size)
      self
    end
  end
end
