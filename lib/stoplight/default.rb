# coding: utf-8

module Stoplight
  module Default
    ERROR_HANDLER = lambda do |error, handler|
      handler.handle(error)
    end

    # These exceptions are dangerous to rescue as rescuing them
    # would interfere with things we should not interfere with.
    AVOID_RESCUING = [
      NoMemoryError,
      SignalException,
      Interrupt,
      SystemExit
    ].freeze

    module AllExceptionsExceptOnesWeMustNotRescue
      def self.===(exception)
        AVOID_RESCUING.none? { |ar| ar === exception }
      end
    end

    DATA_STORE = DataStore::Memory.new

    ERROR_NOTIFIER = -> (error) { warn error }

    FALLBACK = nil

    FORMATTER = lambda do |light, from_color, to_color, error|
      words = ['Switching', light.name, 'from', from_color, 'to', to_color]
      words += ['because', error.class, error.message] if error
      words.join(' ')
    end

    NOTIFIERS = [
      Notifier::IO.new($stderr)
    ].freeze

    THRESHOLD = 3

    TIMEOUT = 60.0
  end
end
