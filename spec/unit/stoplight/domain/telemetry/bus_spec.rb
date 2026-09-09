# frozen_string_literal: true

RSpec.describe Stoplight::Domain::Telemetry::Bus do
  subject(:bus) { described_class.new(error_notifier:) }

  let(:error_notifier) { instance_spy(Proc) }

  def envelope(payload)
    Stoplight::Domain::Telemetry::Envelope.new(
      system_name: "sys",
      light_name: "light",
      occurred_at: Time.at(0),
      payload:
    )
  end

  let(:run_completed) do
    Stoplight::Domain::Telemetry::RunCompleted.new(
      outcome: :success,
      color: "green",
      duration_ms: 1.0,
      failure: nil,
      fallback_used: false,
      retry_after: nil
    )
  end

  let(:traffic_breached) do
    Stoplight::Domain::Telemetry::TrafficBreached.new(
      from_color: "green",
      to_color: "red",
      policy: "error_rate",
      failure: nil,
      metrics: nil
    )
  end

  describe "#subscribe and #publish" do
    subject(:received) { [] }

    context "when subscribed to event class" do
      let(:published_event) { envelope(run_completed) }

      it "delivers an event to a handler" do
        expect do |handler|
          bus.subscribe(Stoplight::Domain::Telemetry::RunCompleted, &handler)
          bus.publish(published_event)
        end.to yield_with_args(published_event)
      end
    end

    context "when subscribed to a different class" do
      let(:published_event) { envelope(run_completed) }

      it "does not deliver an event to a handler" do
        expect do |handler|
          bus.subscribe(Stoplight::Domain::Telemetry::TrafficBreached, &handler)
          bus.publish(published_event)
        end.not_to yield_control
      end
    end

    context "when subscribed without a filter" do
      let(:published_event_1) { envelope(run_completed) }
      let(:published_event_2) { envelope(traffic_breached) }

      it "delivers every event to a firehose handler in order" do
        expect do |handler|
          bus.subscribe(&handler)
          bus.publish(published_event_1)
          bus.publish(published_event_2)
        end.to yield_successive_args(published_event_1, published_event_2)
      end
    end

    context "with multiple subscribers to the same event type" do
      let(:published_event) { envelope(run_completed) }
      let(:received) { [] }

      it "delivers to multiple handlers in subscription order" do
        bus.subscribe(Stoplight::Domain::Telemetry::RunCompleted) { received << :first }
        bus.subscribe(Stoplight::Domain::Telemetry::RunCompleted) { received << :second }

        bus.publish(published_event)

        expect(received).to eq([:first, :second])
      end
    end

    context "with StateTransitioned handler" do
      let(:not_state_transition_event) { envelope(run_completed) }
      let(:state_transition_event) { envelope(traffic_breached) }

      it "delivers only state-transition events to a handler" do
        expect do |handler|
          bus.subscribe(Stoplight::Domain::Telemetry::StateTransitioned, &handler)

          bus.publish(state_transition_event)
          bus.publish(not_state_transition_event)
        end.to yield_with_args(state_transition_event)
      end
    end

    context "without a handler block" do
      it "raises ArgumentError" do
        expect { bus.subscribe(Stoplight::Domain::Telemetry::RunCompleted) }.to raise_error(ArgumentError)
      end
    end

    context "with an invalid filter" do
      subject(:bus) { described_class.new(error_notifier:, max_subscriptions: 1) }

      it "raises ArgumentError instead of comparing it against event classes" do
        expect { bus.subscribe("not_a_class") {} }.to raise_error(ArgumentError, /filter/)
      end

      it "does not register the invalid subscription" do
        expect { bus.subscribe("not_a_class") {} }.to raise_error(ArgumentError)
        expect { bus.subscribe(Stoplight::Domain::Telemetry::RunCompleted) {} }.not_to raise_error
      end

      it "leaves the bus usable for subsequent subscribers" do
        expect { bus.subscribe(42) {} }.to raise_error(ArgumentError)

        expect do |handler|
          bus.subscribe(Stoplight::Domain::Telemetry::RunCompleted, &handler)
          bus.publish(envelope(run_completed))
        end.to yield_control
      end

      it "does not break unsubscribe for subscriptions made before the bad call" do
        subscription = bus.subscribe(Stoplight::Domain::Telemetry::RunCompleted) {}

        expect { bus.subscribe(:invalid) {} }.to raise_error(ArgumentError)

        expect { bus.unsubscribe(subscription) }.not_to raise_error
      end
    end

    context "with a filter that matches no event class" do
      it "raises ArgumentError instead of registering a dead subscription" do
        expect { bus.subscribe(Comparable) {} }.to raise_error(ArgumentError, /does not match/)
      end
    end

    context "when the subscription cap is reached" do
      subject(:bus) { described_class.new(error_notifier:, max_subscriptions: 1) }

      it "raises Stoplight::Error::TooManySubscriptions" do
        bus.subscribe(Stoplight::Domain::Telemetry::RunCompleted) {}

        expect { bus.subscribe(Stoplight::Domain::Telemetry::RunCompleted) {} }
          .to raise_error(Stoplight::Error::TooManySubscriptions)
      end
    end

    context "when subscribing during a publish" do
      let(:received) { [] }

      it "takes effect only on the next publish, not the one in progress" do
        bus.subscribe(Stoplight::Domain::Telemetry::RunCompleted) do
          bus.subscribe(Stoplight::Domain::Telemetry::RunCompleted) { received << :late }
        end

        bus.publish(envelope(run_completed))
        expect(received).to be_empty

        bus.publish(envelope(run_completed))
        expect(received).to eq([:late])
      end
    end
  end

  describe "handler error isolation" do
    let(:boom) { StandardError.new("boom") }
    let(:event) { envelope(run_completed) }

    it "routes a raising handler's error to the error notifier" do
      bus.subscribe(Stoplight::Domain::Telemetry::RunCompleted) { raise boom }

      bus.publish(event)

      expect(error_notifier).to have_received(:call).with(boom)
    end

    it "still delivers to the remaining handlers" do
      bus.subscribe(Stoplight::Domain::Telemetry::RunCompleted) { raise boom }

      expect do |handler|
        bus.subscribe(Stoplight::Domain::Telemetry::RunCompleted, &handler)
        bus.publish(event)
      end.to yield_with_args(event)
    end

    it "does not raise out of publish when the error notifier itself raises" do
      allow(error_notifier).to receive(:call).and_raise(StandardError.new("notifier boom"))
      bus.subscribe(Stoplight::Domain::Telemetry::RunCompleted) { raise boom }

      expect { bus.publish(event) }.not_to raise_error
    end

    it "still delivers to the remaining handlers when the error notifier itself raises" do
      allow(error_notifier).to receive(:call).and_raise(StandardError.new("notifier boom"))
      bus.subscribe(Stoplight::Domain::Telemetry::RunCompleted) { raise boom }

      expect do |handler|
        bus.subscribe(Stoplight::Domain::Telemetry::RunCompleted, &handler)
        bus.publish(event)
      end.to yield_with_args(event)
    end

    it "does not raise out of publish" do
      bus.subscribe(Stoplight::Domain::Telemetry::RunCompleted) { raise boom }

      expect { bus.publish(event) }.not_to raise_error
    end
  end

  describe "#unsubscribe" do
    let(:event) { envelope(run_completed) }

    it "stops delivery to the removed handler" do
      expect do |handler|
        subscription = bus.subscribe(Stoplight::Domain::Telemetry::RunCompleted, &handler)
        bus.unsubscribe(subscription)
        bus.publish(event)
      end.not_to yield_control
    end

    it "removes a firehose handler from every event class" do
      subscription = bus.subscribe {}

      bus.unsubscribe(subscription)

      expect(Stoplight::Domain::Telemetry::Bus::EVENT_CLASSES).to all(satisfy { |klass| !bus.subscribed?(klass) })
    end

    it "leaves other subscriptions to the same class intact" do
      expect do |handler_1|
        removed = bus.subscribe(Stoplight::Domain::Telemetry::RunCompleted, &handler_1)

        expect do |handler_2|
          bus.subscribe(Stoplight::Domain::Telemetry::RunCompleted, &handler_2)
          bus.unsubscribe(removed)
          bus.publish(event)
        end.to yield_with_args(event)
      end.not_to yield_control
    end

    it "is a no-op when the token was already removed" do
      subscription = bus.subscribe(Stoplight::Domain::Telemetry::RunCompleted) {}
      bus.unsubscribe(subscription)

      expect { bus.unsubscribe(subscription) }.not_to raise_error
    end

    it "is a no-op for an unknown token" do
      expect { bus.unsubscribe(Stoplight::Domain::Telemetry::Subscription.new) }.not_to raise_error
    end
  end

  describe "#subscribed?" do
    it "is false when no handler covers the event class" do
      bus.subscribe(Stoplight::Domain::Telemetry::TrafficBreached) {}

      expect(bus).not_to be_subscribed(Stoplight::Domain::Telemetry::RunCompleted)
    end

    it "is true when a handler subscribes to that exact class" do
      bus.subscribe(Stoplight::Domain::Telemetry::RunCompleted) {}

      expect(bus).to be_subscribed(Stoplight::Domain::Telemetry::RunCompleted)
    end

    it "is true for any event class when a firehose handler is subscribed" do
      bus.subscribe {}

      expect(bus).to be_subscribed(Stoplight::Domain::Telemetry::RunCompleted)
      expect(bus).to be_subscribed(Stoplight::Domain::Telemetry::LightRegistered)
    end

    it "is true for transition classes when a StateTransitioned handler is subscribed" do
      bus.subscribe(Stoplight::Domain::Telemetry::StateTransitioned) {}

      expect(bus).to be_subscribed(Stoplight::Domain::Telemetry::TrafficBreached)
      expect(bus).not_to be_subscribed(Stoplight::Domain::Telemetry::RunCompleted)
    end
  end

  describe "EVENT_CLASSES" do
    it "mirrors the event type union" do
      expect(described_class::EVENT_CLASSES).to contain_exactly(
        Stoplight::Domain::Telemetry::RunCompleted,
        Stoplight::Domain::Telemetry::TrafficBreached,
        Stoplight::Domain::Telemetry::RecoveryStarted,
        Stoplight::Domain::Telemetry::RecoverySucceeded,
        Stoplight::Domain::Telemetry::RecoveryFailed,
        Stoplight::Domain::Telemetry::LockChanged,
        Stoplight::Domain::Telemetry::RecoveryProbeCompleted,
        Stoplight::Domain::Telemetry::LightRegistered
      )
    end
  end
end
