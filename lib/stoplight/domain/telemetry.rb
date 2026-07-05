# frozen_string_literal: true

module Stoplight
  module Domain
    class Telemetry
      EVENT_CLASSES = [
        RunCompleted,
        TrafficBreached,
        RecoveryStarted,
        RecoverySucceeded,
        RecoveryFailed,
        LockChanged,
        RecoveryProbeCompleted,
        LightRegistered
      ].freeze
    end
  end
end
