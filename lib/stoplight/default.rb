# coding: utf-8

module Stoplight
  module Default
    ERROR_HANDLER = lambda do |error|
      classes = [
        Interrupt,
        NoMemoryError,
        SignalException,
        SystemExit
      ]
      raise error if classes.any? { |klass| error.is_a?(klass) }
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
