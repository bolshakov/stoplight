# coding: utf-8

module Stoplight
  class Light
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
      sync_settings

      if green?
        run_code
      else
        if Stoplight.attempts(name).zero?
          message = "Switching #{name} stoplight from green to red."
          Stoplight.notifiers.each { |notifier| notifier.notify(message) }
        end

        run_fallback
      end
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
      Stoplight.set_threshold(name, threshold.to_i)
      self
    end

    # Attribute readers

    # @return [Object]
    # @raise [Error::RedLight]
    def fallback
      return @fallback if defined?(@fallback)
      fail Error::RedLight
    end

    # @return (see Stoplight.green?)
    def green?
      Stoplight.green?(name)
    end

    # @return (see Stoplight.red?)
    def red?
      !green?
    end

    # @return (see Stoplight.threshold)
    def threshold
      Stoplight.threshold(name)
    end

    private

    def error_allowed?(error)
      allowed_errors.any? { |klass| error.is_a?(klass) }
    end

    def run_code
      result = code.call
      Stoplight.clear_failures(name)
      result
    rescue => error
      if error_allowed?(error)
        Stoplight.clear_failures(name)
      else
        Stoplight.record_failure(name, error)
      end

      raise
    end

    def run_fallback
      Stoplight.record_attempt(name)
      fallback.call
    end

    def sync_settings
      Stoplight.set_threshold(name, threshold)
    end
  end
end
