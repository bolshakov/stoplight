# frozen_string_literal: true

module Stoplight
  module Error
    AVOID_RESCUING = [
      NoMemoryError,
      ScriptError,
      SecurityError,
      SignalException,
      SystemExit,
      SystemStackError
    ].freeze

    Base = Class.new(StandardError)
    IncorrectColor = Class.new(Base)
    RedLight = Class.new(Base)
  end
end
