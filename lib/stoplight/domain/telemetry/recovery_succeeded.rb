# frozen_string_literal: true

module Stoplight
  module Domain
    module Telemetry
      # state_transitioned variant: recovery policy resumed traffic.
      RecoverySucceeded = Data.define(
        :from_color,
        :to_color,
        :policy,
        :metrics
      )

      class RecoverySucceeded
        include StateTransitioned
      end
    end
  end
end
