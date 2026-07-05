# frozen_string_literal: true

module Stoplight
  module Domain
    class Telemetry
      # state_transitioned variant: traffic control tripped the light.
      TrafficBreached = Data.define(
        :from_color,
        :to_color,
        :policy,
        :failure,
        :metrics
      )

      class TrafficBreached
        include StateTransitioned
      end
    end
  end
end
