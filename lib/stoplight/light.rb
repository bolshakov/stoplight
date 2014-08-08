# coding: utf-8

module Stoplight
  class Light
    attr_reader :code
    attr_reader :name

    DEFAULT_FAILURE_THRESHOLD = 3

    class << self
      def data_store(data_store = nil)
        @data_store = data_store if data_store
        @data_store = DataStore::Memory.new unless defined?(@data_store)
        @data_store
      end

      def green?(name)
        case data_store.state(name)
        when DataStore::STATE_LOCKED_GREEN
          true
        when DataStore::STATE_LOCKED_RED
          false
        else
          data_store.failures(name).size < failure_threshold(name)
        end
      end

      # Returns names of all known stoplights.
      def names
        data_store.names
      end

      def failure_threshold(name)
        data_store.failure_threshold(name) || DEFAULT_FAILURE_THRESHOLD
      end
    end

    def initialize(name, &code)
      @name = name
      @code = code
    end

    def with_allowed_errors(errors)
      @allowed_errors = errors
      self
    end

    def allowed_errors
      @allowed_errors ||= []
    end

    def with_fallback(&fallback)
      @fallback = fallback
      self
    end

    def with_threshold(threshold)
      self.class.data_store.set_failure_threshold(name, threshold)
      self
    end

    def fallback
      return @fallback if defined?(@fallback)
      fail Error::NoFallback
    end

    def run
      sync_settings # REVIEW: Maybe this should be in #initialize.

      if self.class.green?(name)
        run_code
      else
        run_fallback
      end
    end

    private

    def allow_error?(error)
      allowed_errors.any? { |klass| error.is_a?(klass) }
    end

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

    def run_fallback
      self.class.data_store.record_attempt(name)
      fallback.call
    end

    def sync_settings
      threshold = self.class.failure_threshold(name)
      self.class.data_store.set_failure_threshold(name, threshold)
    end
  end
end
