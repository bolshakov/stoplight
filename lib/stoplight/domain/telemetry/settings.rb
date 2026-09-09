# frozen_string_literal: true

module Stoplight
  module Domain
    module Telemetry
      # The serializable subset of a light's configuration.
      Settings = Data.define(
        :cool_off_time,
        :threshold,
        :recovery_threshold,
        :window_size,
        :tracked_errors,
        :skipped_errors,
        :traffic_control,
        :traffic_control_params,
        :traffic_recovery,
        :traffic_recovery_params
      )
    end
  end
end
