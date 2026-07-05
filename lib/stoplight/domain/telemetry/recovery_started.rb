# frozen_string_literal: true

module Stoplight
  module Domain
    class Telemetry
      # state_transitioned variant: cool-off elapsed and the first probe explicitly entered recovery.
      RecoveryStarted = Data.define(
        :from_color,
        :to_color,
        :breached_at
      )

      class RecoveryStarted
        include StateTransitioned
      end
    end
  end
end
