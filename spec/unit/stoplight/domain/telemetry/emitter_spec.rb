# frozen_string_literal: true

RSpec.describe Stoplight::Domain::Telemetry::Emitter do
  subject(:emitter) { described_class.new(bus:, clock:, system_name:, light_name:, error_notifier:) }

  let(:bus) { instance_double(Stoplight::Domain::Telemetry) }
  let(:clock) { instance_double(NullClock) }
  let(:system_name) { SecureRandom.uuid }
  let(:light_name) { SecureRandom.uuid }
  let(:error_notifier) { instance_spy(Proc) }

  describe "#subscribed?" do
    let(:event_type) { Stoplight::Domain::Telemetry::RecoveryFailed }

    it "delegates to the bus" do
      allow(bus).to receive(:subscribed?).with(event_type).and_return(true)

      expect(emitter).to be_subscribed(event_type)
    end
  end

  describe "#emit" do
    context "when subscribed to event" do
      let(:event_type) { Stoplight::Domain::Telemetry::RecoveryFailed }
      let(:event) { instance_double(event_type) }
      let(:occurred_at) { Time.at(0) }

      before do
        allow(bus).to receive(:subscribed?).with(event_type).and_return(true)
      end

      it "emits an event " do
        envelope = Stoplight::Domain::Telemetry::Envelope.new(
          system_name:, light_name:, occurred_at:, payload: event
        )

        expect(bus).to receive(:publish).with(envelope)
        expect(clock).to receive(:current_time).and_return(occurred_at)

        emitter.emit(event_type) { event }
      end
    end

    context "when not subscribed to event" do
      let(:event_type) { Stoplight::Domain::Telemetry::RecoveryFailed }

      before do
        allow(bus).to receive(:subscribed?).with(event_type).and_return(false)
      end

      it "does not emit an event nor instantiate it " do
        expect(bus).not_to receive(:publish)

        expect do |event_factory|
          emitter.emit(event_type, &event_factory)
        end.not_to yield_control
      end
    end

    context "when building the event raises" do
      let(:event_type) { Stoplight::Domain::Telemetry::RecoveryFailed }
      let(:boom) { StandardError.new("boom") }

      before do
        allow(bus).to receive(:subscribed?).with(event_type).and_return(true)
        allow(clock).to receive(:current_time).and_return(Time.at(0))
      end

      it "routes the error to the error notifier instead of the caller" do
        expect(bus).not_to receive(:publish)

        expect { emitter.emit(event_type) { raise boom } }.not_to raise_error

        expect(error_notifier).to have_received(:call).with(boom)
      end

      it "does not raise when the error notifier itself raises" do
        allow(error_notifier).to receive(:call).and_raise(StandardError.new("notifier boom"))

        expect { emitter.emit(event_type) { raise boom } }.not_to raise_error
      end
    end
  end
end
