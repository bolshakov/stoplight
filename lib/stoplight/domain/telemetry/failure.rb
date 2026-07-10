# frozen_string_literal: true

module Stoplight
  module Domain
    class Telemetry
      # Carries the live exception.
      Failure = Data.define(
        :exception,
        :tracked
      )
    end
  end
end
