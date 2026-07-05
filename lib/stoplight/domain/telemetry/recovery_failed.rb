# frozen_string_literal: true

module Stoplight
  module Domain
    class Telemetry
      # state_transitioned variant: recovery policy sent the light back to red.
      RecoveryFailed = Data.define(
        :from_color,
        :to_color,
        :policy,
        :failure,
        :metrics
      )

      class RecoveryFailed
        include StateTransitioned
      end
    end
  end
end
