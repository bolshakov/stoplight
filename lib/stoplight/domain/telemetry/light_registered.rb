# frozen_string_literal: true

module Stoplight
  module Domain
    module Telemetry
      # Emitted once per (process instance, system, light) when the light's configuration first materializes.
      LightRegistered = Data.define(
        :settings
      )
    end
  end
end
