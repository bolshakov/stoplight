# frozen_string_literal: true

module Stoplight
  module Domain
    module TrafficRecovery
      # Values match Color's, so strategies that return Color constants keep working
      RECOVERED = :green
      PROBING = :yellow
      FAILED_TO_RECOVER = :red
    end
  end
end
