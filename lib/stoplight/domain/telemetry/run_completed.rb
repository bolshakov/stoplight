# frozen_string_literal: true

module Stoplight
  module Domain
    module Telemetry
      # Emitted for every Light#run.
      RunCompleted = Data.define(
        :outcome,
        :color,
        :duration_ms,
        :failure,
        :fallback_used,
        :retry_after
      )
    end
  end
end
