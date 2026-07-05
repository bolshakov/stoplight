# frozen_string_literal: true

module Stoplight
  # Public face of the telemetry bus. The bus and its events live in the domain layer
  # (+Domain::Telemetry+); this namespace re-exports them so callers never reference the
  # +Domain::+ boundary - mirroring +Stoplight::Notifier+ and +Stoplight::DataStore+.
  module Telemetry
    RunCompleted = Domain::Telemetry::RunCompleted
    TrafficBreached = Domain::Telemetry::TrafficBreached
    RecoveryStarted = Domain::Telemetry::RecoveryStarted
    RecoverySucceeded = Domain::Telemetry::RecoverySucceeded
    RecoveryFailed = Domain::Telemetry::RecoveryFailed
    LockChanged = Domain::Telemetry::LockChanged
    RecoveryProbeCompleted = Domain::Telemetry::RecoveryProbeCompleted
    LightRegistered = Domain::Telemetry::LightRegistered

    StateTransitioned = Domain::Telemetry::StateTransitioned
  end
end
