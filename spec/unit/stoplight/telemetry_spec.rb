# frozen_string_literal: true

RSpec.describe Stoplight::Telemetry do
  # The public namespace re-exports the constants callers name explicitly - the event classes they
  # pass to +subscribe+ and the +StateTransitioned+ marker - so they never reference the Domain::
  # boundary. Each alias must be the very same object as its internal counterpart. Types callers only
  # receive (Envelope, Failure, ...) are not aliased here: nobody writes their names.
  aliased = %i[
    RunCompleted
    TrafficBreached
    RecoveryStarted
    RecoverySucceeded
    RecoveryFailed
    LockChanged
    RecoveryProbeCompleted
    LightRegistered
    StateTransitioned
  ]

  aliased.each do |name|
    it "exposes #{name} as an alias of Domain::Telemetry::#{name}" do
      expect(described_class.const_get(name)).to equal(Stoplight::Domain::Telemetry.const_get(name))
    end
  end
end
