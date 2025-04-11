# frozen_string_literal: true

module Stoplight
  # TODO: reference constants from Stoplight::Light::Config
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

    WINDOW_SIZE = Float::INFINITY

    warn "You're using the deprecated constants in Stoplight::Default. Please consult the upgrade guide for more information."
  end
end
