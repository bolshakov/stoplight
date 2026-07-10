# frozen_string_literal: true

RSpec.describe Stoplight::Domain::Telemetry::Emitter do
  subject(:emitter) { described_class.new(bus:, clock:, system_name:, light_name:) }

  let(:bus) { instance_double(Stoplight::Domain::Telemetry) }
  let(:clock) { instance_double(NullClock) }
  let(:system_name) { SecureRandom.uuid }
  let(:light_name) { SecureRandom.uuid }

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
  end
end
