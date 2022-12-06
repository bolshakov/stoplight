# frozen_string_literal: true

module Stoplight
  class Light # rubocop:disable Style/Documentation
    include Runnable

    # @return [Proc]
    attr_reader :code
    # @return [Float]
    attr_reader :cool_off_time
    # @return [Proc]
    attr_reader :error_handler
    # @return [Proc]
    attr_reader :error_notifier
    # @return [Proc, nil]
    attr_reader :fallback
    # @return [String]
    attr_reader :name
    # @return [Array<Notifier::Base>]
    attr_reader :notifiers
    # @return [Fixnum]
    attr_reader :threshold

    # @return [Stoplight::Strategy::Base]
    attr_reader :strategy

    class << self
      # @return [DataStore::Base]
      attr_accessor :default_data_store
      # @return [Proc]
      attr_accessor :default_error_notifier
      # @return [Array<Notifier::Base>]
      attr_accessor :default_notifiers
    end

    @default_data_store = Default::DATA_STORE
    @default_error_notifier = Default::ERROR_NOTIFIER
    @default_notifiers = Default::NOTIFIERS

    # @param name [String]
    # @yield []
    def initialize(name, &code)
      @name = name
      @code = code

      @strategy_class = Default::Strategy
      with_cool_off_time(Default::COOL_OFF_TIME)
      with_data_store(self.class.default_data_store)
      with_error_handler(&Default::ERROR_HANDLER)
      with_error_notifier(&self.class.default_error_notifier)
      with_fallback(&Default::FALLBACK)
      with_notifiers(self.class.default_notifiers)
      with_threshold(Default::THRESHOLD)
    end

    # @param cool_off_time [Float]
    # @return [self]
    def with_cool_off_time(cool_off_time)
      @cool_off_time = cool_off_time
      self
    end

    # @param data_store [DataStore::Base]
    # @return [self]
    def with_data_store(data_store)
      @strategy = @strategy_class.new(data_store)
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
      @notifiers = notifiers
      self
    end

    # @param threshold [Fixnum]
    # @return [self]
    def with_threshold(threshold)
      @threshold = threshold
      self
    end
  end
end
