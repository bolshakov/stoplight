# frozen_string_literal: true

module Stoplight
  module Wiring
    SystemContainer = Container.with(
      traffic_recovery: Stoplight::Domain::TrafficRecovery::ConsecutiveSuccesses.new
    )
  end
end
