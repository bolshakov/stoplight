# coding: utf-8

module Stoplight
  class Light
    DEFAULT_FAILURE_THRESHOLD = 3

    # @param data_store [DataStore::Base, nil]
    # @return [DataStore::Base]
    def self.data_store(data_store = nil)
      @data_store = data_store if data_store
      @data_store = DataStore::Memory.new unless defined?(@data_store)
      @data_store
    end

    # @return [Boolean]
    def self.green?(name)
      data_store.failures(name).size < failure_threshold(name)
    end

    # Returns names of all known stoplights.
    def self.names
      data_store.names
    end

    def self.failure_threshold(name)
      data_store.failure_threshold(name) || DEFAULT_FAILURE_THRESHOLD
    end

    # @yield []
    # @return [Light]
    def with_code(&code)
      @code = code
      self
    end

    def with_allowed_errors(errors)
      @allowed_errors = errors
      self
    end

    def allowed_errors
      @allowed_errors ||= []
    end

    def allow_error?(error)
      allowed_errors.any? { |klass| error.is_a?(klass) }
    end

    # @yield []
    # @return [Light]
    def with_fallback(&fallback)
      @fallback = fallback
      self
    end

    # @param name [String]
    # @return [Light]
    def with_name(name)
      @name = name
      self
    end

    def with_threshold(threshold)
      self.class.data_store.set_failure_threshold(name, threshold)
      self
    end

    # @return [Proc]
    # @raise [Error::NoCode]
    def code
      return @code if defined?(@code)
      fail Error::NoCode
    end

    # @return [Proc]
    # @raise [Error::NoFallback]
    def fallback
      return @fallback if defined?(@fallback)
      fail Error::NoFallback
    end

    # @return [String]
    # @raise [Error::NoName]
    def name
      return @name if defined?(@name)
      fail Error::NoName
    end

    # @return [Object]
    # @raise (see #code)
    def run_code
      result = code.call
      self.class.data_store.clear_failures(name)
      result
    rescue => e # REVIEW: rescue Exception?
      if allow_error?(e)
        self.class.data_store.clear_failures(name)
      else
        self.class.data_store.record_failure(name, e)
      end

      raise
    end

    # @return [Object]
    # @raise (see #fallback)
    def run_fallback
      self.class.data_store.record_attempt(name)
      fallback.call
    end

    def run
      sync_settings # REVIEW: Maybe this should be in #initialize.

      if self.class.green?(name)
        run_code
      else
        run_fallback
      end
    end

    def sync_settings
      threshold = self.class.failure_threshold(name)
      self.class.data_store.set_failure_threshold(name, threshold)
    end
  end
end
