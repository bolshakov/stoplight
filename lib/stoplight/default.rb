# frozen_string_literal: true

module Stoplight
  module Default
    COOL_OFF_TIME = 60.0

    DATA_STORE = DataStore::Memory.new

    ERROR_NOTIFIER = ->(error) { warn error }

    FORMATTER = lambda do |light, from_color, to_color, error|
      words = ["Switching", light.name, "from", from_color, "to", to_color]
      words += ["because", error.class, error.message] if error
      words.join(" ")
    end

    NOTIFIERS = [
      Notifier::IO.new($stderr)
    ].freeze

    THRESHOLD = 3

    WINDOW_SIZE = 30 * 24 * 60 * 60 # 14 days

    TRACKED_ERRORS = [StandardError].freeze
    SKIPPED_ERRORS = [
      NoMemoryError,
      ScriptError,
      SecurityError,
      SignalException,
      SystemExit,
      SystemStackError
    ].freeze
  end
end
