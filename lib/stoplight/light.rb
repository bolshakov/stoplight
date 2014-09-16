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

      case color
      when DataStore::COLOR_GREEN
        run_green
      when DataStore::COLOR_YELLOW
        run_yellow
      when DataStore::COLOR_RED
        run_red
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
      fail Error::RedLight, name
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

    # @return (see Stoplight::DataStore::Base#get_color)
    def color
      Stoplight.data_store.get_color(name)
    end

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

    def run_green
      code.call.tap { Stoplight.data_store.clear_failures(name) }
    rescue => error
      handle_error(error)
      raise
    end

    def run_yellow
      run_green.tap { notify(DataStore::COLOR_RED, DataStore::COLOR_GREEN) }
    end

    def run_red
      if Stoplight.data_store.record_attempt(name) == 1
        notify(DataStore::COLOR_GREEN, DataStore::COLOR_RED)
      end
      fallback.call
    end

    def handle_error(error)
      if error_allowed?(error)
        Stoplight.data_store.clear_failures(name)
      else
        Stoplight.data_store.record_failure(name, Failure.create(error))
      end
    end

    def error_allowed?(error)
      allowed_errors.any? { |klass| error.is_a?(klass) }
    end

    def notify(from_color, to_color)
      Stoplight.notifiers.each do |notifier|
        notifier.notify(self, from_color, to_color)
      end
    end
  end
end
