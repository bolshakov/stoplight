# frozen_string_literal: true

RSpec.describe Stoplight::Domain::Telemetry::Consumer do
  subject(:consumer) { described_class.new(bus) }

  let(:bus) { Stoplight::Domain::Telemetry::Bus.new(error_notifier: instance_spy(Proc)) }

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

  describe "#subscribe" do
    it "forwards to the wrapped bus" do
      expect do |handler|
        consumer.subscribe(Stoplight::Domain::Telemetry::RunCompleted, &handler)
        bus.publish(envelope(run_completed))
      end.to yield_with_args(envelope(run_completed))
    end
  end

  describe "#unsubscribe" do
    it "forwards to the wrapped bus, removing the subscription" do
      received = []
      subscription = consumer.subscribe(Stoplight::Domain::Telemetry::RunCompleted) { |e| received << e }

      consumer.unsubscribe(subscription)
      bus.publish(envelope(run_completed))

      expect(received).to be_empty
    end
  end

  describe "producer-side isolation" do
    it "does not expose #publish" do
      expect(consumer).not_to respond_to(:publish)
    end

    it "does not expose #subscribed?" do
      expect(consumer).not_to respond_to(:subscribed?)
    end
  end
end
