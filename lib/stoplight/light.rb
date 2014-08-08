# coding: utf-8

module Stoplight
  class Light
    DEFAULT_FAILURE_THRESHOLD = 3

    attr_reader :allowed_errors
    attr_reader :code
    attr_reader :name

    def initialize(name, &code)
      @allowed_errors = []
      @code = code.to_proc
      @name = name.to_s
    end

    def run
      sync_settings

      if green?
        run_code
      else
        run_fallback
      end
    end

    # Fluent builders

    def with_allowed_errors(allowed_errors)
      @allowed_errors = allowed_errors.to_a
      self
    end

    def with_fallback(&fallback)
      @fallback = fallback.to_proc
      self
    end

    def with_threshold(threshold)
      Stoplight.data_store.set_failure_threshold(threshold.to_i)
      self
    end

    # Attribute readers

    def fallback
      return @fallback if defined?(@fallback)
      fail Error::NoFallback
    end

    def green?
      Stoplight.green?(name)
    end

    def red?
      !green?
    end

    def threshold
      Stoplight.failure_threshold(name)
    end

    private

    def error_allowed?(error)
      allowed_errors.any? { |klass| error.is_a?(klass) }
    end

    def run_code
      result = code.call
      Stoplight.data_store.clear_failures(name)
      result
    rescue => error
      if error_allowed?(error)
        Stoplight.data_store.clear_failures(name)
      else
        Stoplight.data_store.record_failure(name, error)
      end

      raise
    end

    def run_fallback
      Stoplight.data_store.record_attempt(name)
      fallback.call
    end

    def sync_settings
      Stoplight.data_store.set_failure_threshold(name, threshold)
    end
  end
end
