# frozen_string_literal: true

RSpec.describe Stoplight::Domain::Telemetry::StateTransitioned do
  let(:transition_events) do
    [
      Stoplight::Domain::Telemetry::TrafficBreached,
      Stoplight::Domain::Telemetry::RecoveryStarted,
      Stoplight::Domain::Telemetry::RecoverySucceeded,
      Stoplight::Domain::Telemetry::RecoveryFailed,
      Stoplight::Domain::Telemetry::LockChanged
    ]
  end

  it "is included by every state transition event" do
    expect(transition_events).to all(be < described_class)
  end

  it "is not included by any other event" do
    other_events = Stoplight::Domain::Telemetry::Bus::EVENT_CLASSES - transition_events

    expect(other_events).to all(satisfy { |event_class| !(event_class < described_class) })
  end
end
