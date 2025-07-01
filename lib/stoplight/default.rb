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

    NOTIFIERS = [Notifier::IO.new($stderr)].freeze

    THRESHOLD = 3
    RECOVERY_THRESHOLD = 1

    WINDOW_SIZE = nil

    TRACKED_ERRORS = [StandardError].freeze
    SKIPPED_ERRORS = [].freeze

    TRAFFIC_CONTROL = TrafficControl::ConsecutiveErrors.new
    TRAFFIC_RECOVERY = TrafficRecovery::ConsecutiveSuccesses.new
  end
end
