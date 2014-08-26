# coding: utf-8

module Stoplight
  class Light # rubocop:disable Metrics/ClassLength
    # @return [Array<Exception>]
    attr_reader :allowed_errors

    # @return [Proc]
    attr_reader :code

    # @return [String]
    attr_reader :name

    # @param name [String]
    # @yield []
    def initialize(name, &code)
      @allowed_errors = []
      @code = code.to_proc
      @name = name.to_s
    end

    # @return [Object]
    # @raise [Error::RedLight]
    # @see #fallback
    # @see #green?
    def run
      sync
      red? ? run_fallback : run_code
    end

    # Fluent builders

    # @param allowed_errors [Array<Exception>]
    # @return [self]
    def with_allowed_errors(allowed_errors)
      @allowed_errors = allowed_errors.to_a
      self
    end

    # @yield []
    # @return [self]
    def with_fallback(&fallback)
      @fallback = fallback.to_proc
      self
    end

    # @param threshold [Integer]
    # @return [self]
    def with_threshold(threshold)
      self.threshold = threshold
      self
    end

    # @param timeout [Integer]
    # @return [self]
    def with_timeout(timeout)
      self.timeout = timeout
      self
    end

    # Attribute readers

    # @return [Object]
    # @raise [Error::RedLight]
    def fallback
      return @fallback if defined?(@fallback)
      fail Error::RedLight
    end

    %w(
      green?
      yellow?
      red?
    ).each do |method|
      define_method(method) do
        Stoplight.data_store.public_send(method, name)
      end
    end

    %w(
      get_threshold
      get_timeout
    ).each do |method|
      define_method(method[4..-1]) do
        Stoplight.data_store.public_send(method, name)
      end
    end

    private

    %w(
      sync
      clear
      record_attempt
      clear_attempts
      record_failure
      clear_failures
      clear_state
      clear_threshold
      clear_timeout
    ).each do |method|
      define_method(method) do |*args|
        Stoplight.data_store.public_send(method, name, *args)
      end
      private method
    end

    %w(
      get_attempts
      get_failures
      get_state
    ).each do |method|
      define_method(method[4..-1]) do
        Stoplight.data_store.public_send(method, name)
      end
      private method[4..-1]
    end

    %w(
      set_state
      set_threshold
      set_timeout
    ).each do |method|
      define_method("#{method[4..-1]}=") do |value|
        Stoplight.data_store.public_send(method, name, value)
      end
      private "#{method[4..-1]}="
    end

    def error_allowed?(error)
      allowed_errors.any? { |klass| error.is_a?(klass) }
    end

    def run_code
      result = code.call
      clear_failures
      result
    rescue => error
      if error_allowed?(error)
        clear_failures
      else
        record_failure(Failure.new(error))
      end

      raise
    end

    def run_fallback
      if attempts.zero?
        message = "Switching #{name} stoplight from green to red."
        Stoplight.notifiers.each { |notifier| notifier.notify(message) }
      end

      record_attempt(name)
      fallback.call
    end
  end # rubocop:enable Metrics/ClassLength
end
