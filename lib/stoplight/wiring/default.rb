# frozen_string_literal: true

module Stoplight
  module Wiring
    module Default
      COOL_OFF_TIME = 60.0

      DATA_STORE = Infrastructure::DataStore::Memory.new

      ERROR_NOTIFIER = ->(error) { warn error }

      FORMATTER = Infrastructure::Notifier::Generic::DEFAULT_FORMATTER

      NOTIFIERS = [Infrastructure::Notifier::IO.new($stderr)].freeze

      THRESHOLD = 3
      RECOVERY_THRESHOLD = 1

      WINDOW_SIZE = nil

      TRACKED_ERRORS = [StandardError].freeze
      SKIPPED_ERRORS = [].freeze

      TRAFFIC_CONTROL = Domain::TrafficControl::ConsecutiveErrors.new
      TRAFFIC_RECOVERY = Domain::TrafficRecovery::ConsecutiveSuccesses.new
    end
  end
end
