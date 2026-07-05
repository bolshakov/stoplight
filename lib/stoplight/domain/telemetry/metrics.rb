# frozen_string_literal: true

module Stoplight
  module Domain
    class Telemetry
      # The serializable subset of MetricsSnapshot.
      Metrics = Data.define(
        :successes,
        :errors,
        :consecutive_errors,
        :consecutive_successes
      )
    end
  end
end
