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
      @threshold = sync

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
      result =
        begin
          code.call
        rescue => error
          handle_error(error)
          raise
        end

      Stoplight.data_store.greenify(name)
      result
    end

    def run_yellow
      result = run_green
      notify(DataStore::COLOR_RED, DataStore::COLOR_GREEN)
      result
    end

    def run_red
      Stoplight.data_store.record_attempt(name)
      fallback.call
    end

    def handle_error(error)
      if error_allowed?(error)
        Stoplight.data_store.greenify(name)
      else
        failure = Failure.create(error)
        size = Stoplight.data_store.record_failure(name, failure)
        if size == @threshold
          notify(DataStore::COLOR_GREEN, DataStore::COLOR_RED, failure)
        end
      end
    end

    def error_allowed?(error)
      allowed_errors.any? { |klass| error.is_a?(klass) }
    end

    def notify(from_color, to_color, failure = nil)
      Stoplight.notifiers.each do |notifier|
        begin
          notifier.notify(self, from_color, to_color, failure)
        rescue Error::BadNotifier => error
          warn(error.cause)
        end
      end
    end

    def sync
      Stoplight.data_store.sync(name)
    rescue Error::BadDataStore => error
      warn(error.cause)
      Stoplight.data_store = Stoplight::DataStore::Memory.new
      retry
    end
  end
end
