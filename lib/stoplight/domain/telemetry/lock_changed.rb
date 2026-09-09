# frozen_string_literal: true

module Stoplight
  module Domain
    module Telemetry
      # state_transitioned variant: manual lock override changed.
      LockChanged = Data.define(
        :from_color,
        :to_color,
        :from_state,
        :to_state
      )

      class LockChanged
        include StateTransitioned
      end
    end
  end
end
