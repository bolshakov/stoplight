# frozen_string_literal: true

module Stoplight
  module Error
    HANDLER = lambda do |error|
      raise error if AVOID_RESCUING.any? { |klass| error.is_a?(klass) }
    end

    AVOID_RESCUING = [
      NoMemoryError,
      ScriptError,
      SecurityError,
      SignalException,
      SystemExit,
      SystemStackError,
    ].freeze

    Base = Class.new(StandardError)
    IncorrectColor = Class.new(Base)
    RedLight = Class.new(Base)
  end
end
