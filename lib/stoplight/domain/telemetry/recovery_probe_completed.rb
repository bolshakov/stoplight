# frozen_string_literal: true

module Stoplight
  module Domain
    module Telemetry
      # Emitted for every recovery probe (a run executed while yellow, under the recovery lock).
      RecoveryProbeCompleted = Data.define(
        :outcome,
        :duration_ms,
        :failure,
        :progress
      )
    end
  end
end
