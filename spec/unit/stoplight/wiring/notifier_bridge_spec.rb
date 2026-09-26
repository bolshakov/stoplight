# frozen_string_literal: true

RSpec.describe Stoplight::Wiring::NotifierBridge do
  subject(:bridge) { described_class.new(notifiers:) }

  let(:light_name) { "checkout" }
  let(:notifiers) { [notifier] }
  let(:notifier) { instance_double(NullNotifier) }
  let(:error_notifier) { instance_spy(Proc) }
  let(:bus) { Stoplight::Domain::Telemetry::Bus.new(error_notifier:) }

  def envelope(payload, light_name: self.light_name)
    Stoplight::Domain::Telemetry::Envelope.new(
      system_name: "sys",
      light_name:,
      occurred_at: Time.at(0),
      payload:
    )
  end

  before { bridge.subscribe(bus) }

  describe "TrafficBreached" do
    let(:exception) { KeyError.new("bang") }
    let(:payload) do
      Stoplight::Domain::Telemetry::TrafficBreached.new(
        from_color: Stoplight::Color::GREEN,
        to_color: Stoplight::Color::RED,
        policy: "error_rate",
        failure: Stoplight::Domain::Telemetry::Failure.new(exception:, tracked: true),
        metrics: nil
      )
    end

    it "notifies with the transition and the underlying error" do
      expect(notifier).to receive(:notify).with(
        have_attributes(name: light_name), Stoplight::Color::GREEN, Stoplight::Color::RED, exception
      )

      bus.publish(envelope(payload))
    end
  end

  describe "RecoveryStarted" do
    let(:payload) do
      Stoplight::Domain::Telemetry::RecoveryStarted.new(
        from_color: Stoplight::Color::RED,
        to_color: Stoplight::Color::YELLOW,
        breached_at: Time.at(0)
      )
    end

    it "notifies with the transition and no error" do
      expect(notifier).to receive(:notify).with(
        have_attributes(name: light_name), Stoplight::Color::RED, Stoplight::Color::YELLOW, nil
      )

      bus.publish(envelope(payload))
    end
  end

  describe "RecoverySucceeded" do
    let(:payload) do
      Stoplight::Domain::Telemetry::RecoverySucceeded.new(
        from_color: Stoplight::Color::YELLOW,
        to_color: Stoplight::Color::GREEN,
        policy: "consecutive_successes",
        metrics: nil
      )
    end

    it "notifies with the transition and no error" do
      expect(notifier).to receive(:notify).with(
        have_attributes(name: light_name), Stoplight::Color::YELLOW, Stoplight::Color::GREEN, nil
      )

      bus.publish(envelope(payload))
    end
  end

  describe "RecoveryFailed" do
    context "when the probe itself failed" do
      let(:exception) { KeyError.new("bang") }
      let(:payload) do
        Stoplight::Domain::Telemetry::RecoveryFailed.new(
          from_color: Stoplight::Color::YELLOW,
          to_color: Stoplight::Color::RED,
          policy: "consecutive_successes",
          failure: Stoplight::Domain::Telemetry::Failure.new(exception:, tracked: true),
          metrics: nil
        )
      end

      it "notifies with the transition and the underlying error" do
        expect(notifier).to receive(:notify).with(
          have_attributes(name: light_name), Stoplight::Color::YELLOW, Stoplight::Color::RED, exception
        )

        bus.publish(envelope(payload))
      end
    end

    context "when the probe succeeded but recovery still tripped back to red" do
      let(:payload) do
        Stoplight::Domain::Telemetry::RecoveryFailed.new(
          from_color: Stoplight::Color::YELLOW,
          to_color: Stoplight::Color::RED,
          policy: "consecutive_successes",
          failure: nil,
          metrics: nil
        )
      end

      it "notifies with no error" do
        expect(notifier).to receive(:notify).with(
          have_attributes(name: light_name), Stoplight::Color::YELLOW, Stoplight::Color::RED, nil
        )

        bus.publish(envelope(payload))
      end
    end
  end

  describe "LockChanged" do
    let(:payload) do
      Stoplight::Domain::Telemetry::LockChanged.new(
        from_color: Stoplight::Color::GREEN,
        to_color: Stoplight::Color::RED,
        from_state: :unlocked,
        to_state: :locked
      )
    end

    it "does not notify - manual lock overrides are not legacy notifier events" do
      expect(notifier).not_to receive(:notify)

      bus.publish(envelope(payload))
    end
  end

  describe "events from multiple lights sharing the same system bus" do
    let(:payload) do
      Stoplight::Domain::Telemetry::RecoveryStarted.new(
        from_color: Stoplight::Color::RED,
        to_color: Stoplight::Color::YELLOW,
        breached_at: Time.at(0)
      )
    end

    it "notifies for each light, using its own name" do
      expect(notifier).to receive(:notify).with(
        have_attributes(name: "checkout"), Stoplight::Color::RED, Stoplight::Color::YELLOW, nil
      )
      expect(notifier).to receive(:notify).with(
        have_attributes(name: "billing"), Stoplight::Color::RED, Stoplight::Color::YELLOW, nil
      )

      bus.publish(envelope(payload, light_name: "checkout"))
      bus.publish(envelope(payload, light_name: "billing"))
    end
  end

  describe "multiple notifiers" do
    let(:notifiers) { [notifier, other_notifier] }
    let(:other_notifier) { instance_double(NullNotifier) }
    let(:payload) do
      Stoplight::Domain::Telemetry::RecoveryStarted.new(
        from_color: Stoplight::Color::RED,
        to_color: Stoplight::Color::YELLOW,
        breached_at: Time.at(0)
      )
    end

    it "notifies every notifier" do
      expect(notifier).to receive(:notify)
      expect(other_notifier).to receive(:notify)

      bus.publish(envelope(payload))
    end
  end
end
