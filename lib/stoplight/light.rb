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
      Stoplight.data_store.sync(name)
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
      Stoplight.data_store.set_threshold(name, threshold)
      self
    end

    # @param timeout [Integer]
    # @return [self]
    def with_timeout(timeout)
      Stoplight.data_store.set_timeout(name, timeout)
      self
    end

    # Attribute readers

    # @return [Object]
    # @raise [Error::RedLight]
    def fallback
      return @fallback if defined?(@fallback)
      fail Error::RedLight
    end

    # @return (see Stoplight::DataStore::Base#threshold)
    def threshold
      Stoplight.data_store.get_threshold(name)
    end

    # @return (see Stoplight::DataStore::Base#timeout)
    def timeout
      Stoplight.data_store.get_timeout(name)
    end

    # Colors

    # @return (see Stoplight::DataStore::Base#green?)
    def green?
      Stoplight.data_store.green?(name)
    end

    # @return (see Stoplight::DataStore::Base#yellow?)
    def yellow?
      Stoplight.data_store.yellow?(name)
    end

    # @return (see Stoplight::DataStore::Base#red?)
    def red?
      Stoplight.data_store.red?(name)
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
        Stoplight.data_store.record_failure(Failure.new(error))
      end

      raise
    end

    def run_fallback
      if Stoplight.data_store.attempts(name).zero?
        message = "Switching #{name} stoplight from green to red."
        Stoplight.notifiers.each { |notifier| notifier.notify(message) }
      end

      Stoplight.data_store.record_attempt(name)
      fallback.call
    end
  end
end
