# coding: utf-8

module Stoplight
  class Light
    include Runnable

    # @return [Array<Exception>]
    attr_reader :whitelisted_errors
    # @return [Array<Exception>]
    attr_reader :blacklisted_errors
    # @return [Proc]
    attr_reader :code
    # @return [DataStore::Base]
    attr_reader :data_store
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
    # @return [Float]
    attr_reader :timeout

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

      @whitelisted_errors = Default::WHITELISTED_ERRORS
      @blacklisted_errors = Default::BLACKLISTED_ERRORS
      @data_store = self.class.default_data_store
      @error_notifier = self.class.default_error_notifier
      @fallback = Default::FALLBACK
      @notifiers = self.class.default_notifiers
      @threshold = Default::THRESHOLD
      @timeout = Default::TIMEOUT
    end

    # @param whitelisted_errors [Array<Exception>]
    # @return [self]
    def with_whitelisted_errors(whitelisted_errors)
      @whitelisted_errors = Default::WHITELISTED_ERRORS + whitelisted_errors
      self
    end

    alias_method :with_allowed_errors, :with_whitelisted_errors

    # @param blacklisted_errors [Array<Exception>]
    # @return [self]
    def with_blacklisted_errors(blacklisted_errors)
      @blacklisted_errors = Default::BLACKLISTED_ERRORS + blacklisted_errors
      self
    end

    # @param data_store [DataStore::Base]
    # @return [self]
    def with_data_store(data_store)
      @data_store = data_store
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

    # @param timeout [Float]
    # @return [self]
    def with_timeout(timeout)
      @timeout = timeout
      self
    end
  end
end
