# frozen_string_literal: true

module Stoplight
  module Error
    Base = Class.new(StandardError)
    ConfigurationError = Class.new(Base)
    IncorrectColor = Class.new(Base)
    RedLight = Class.new(Base)
  end
end
