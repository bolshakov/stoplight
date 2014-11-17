# coding: utf-8

module Stoplight
  class Light
    include Runnable

    attr_reader :allowed_errors
    attr_reader :code
    attr_reader :data_store
    attr_reader :error_notifier
    attr_reader :fallback
    attr_reader :name
    attr_reader :notifiers
    attr_reader :threshold
    attr_reader :timeout

    class << self
      attr_accessor :default_data_store
      attr_accessor :default_error_notifier
      attr_accessor :default_notifiers
    end

    @default_data_store = Default::DATA_STORE
    @default_error_notifier = Default::ERROR_NOTIFIER
    @default_notifiers = Default::NOTIFIERS

    def initialize(name, &code)
      @name = name
      @code = code

      @allowed_errors = Default::ALLOWED_ERRORS
      @data_store = self.class.default_data_store
      @error_notifier = self.class.default_error_notifier
      @fallback = Default::FALLBACK
      @notifiers = self.class.default_notifiers
      @threshold = Default::THRESHOLD
      @timeout = Default::TIMEOUT
    end

    def with_allowed_errors(allowed_errors)
      @allowed_errors = Default::ALLOWED_ERRORS + allowed_errors
      self
    end

    def with_data_store(data_store)
      @data_store = data_store
      self
    end

    def with_error_notifier(&error_notifier)
      @error_notifier = error_notifier
      self
    end

    def with_fallback(&fallback)
      @fallback = fallback
      self
    end

    def with_notifiers(notifiers)
      @notifiers = notifiers
      self
    end

    def with_threshold(threshold)
      @threshold = threshold
      self
    end

    def with_timeout(timeout)
      @timeout = timeout
      self
    end
  end
end
