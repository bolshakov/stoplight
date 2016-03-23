# coding: utf-8

module Stoplight
  module Default
    WHITELISTED_ERRORS = [].freeze

    BLACKLISTED_ERRORS = [StandardError].freeze

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
