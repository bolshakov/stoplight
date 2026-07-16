# frozen_string_literal: true

RSpec.describe Stoplight::Domain::Strategies::RedRunStrategy, :freeze do
  subject(:result) { strategy.execute(fallback, state_snapshot:, error_tracking_policy:) { 42 } }

  let(:strategy) do
    described_class.new(
      name:,
      cool_off_time:,
      run_recorder:
    )
  end
  let(:state_snapshot) { instance_double(Stoplight::Domain::StateSnapshot, recovery_scheduled_after: Time.now) }
  let(:error_tracking_policy) { instance_double(Stoplight::Domain::ErrorTrackingPolicy) }
  let(:name) { SecureRandom.uuid }
  let(:cool_off_time) { 60 }
  let(:emitter) { TestTelemetryEmitter.new }
  let(:run_recorder) { Stoplight::Domain::Telemetry::RunRecorder.new(emitter:, color: Stoplight::Color::RED) }

  context "when fallback is provided" do
    let(:fallback) {
      ->(error) {
        @error = error
        "Fallback"
      }
    }

    it "returns fallback" do
      expect(result).to eq("Fallback")

      expect(@error).to eq(nil)
    end

    it "produces RunCompleted event" do
      expect { result }.to emit(Stoplight::Domain::Telemetry::RunCompleted).with(
        outcome: :blocked,
        color: "red",
        duration_ms: nil,
        failure: nil,
        fallback_used: true,
        retry_after: state_snapshot.recovery_scheduled_after
      )
    end
  end

  context "when fallback is not provided" do
    let(:fallback) { nil }

    it "records and raises the error" do
      expect { result }.to raise_error(Stoplight::Error::RedLight, name) { |error|
        expect(error.cool_off_time).to eq(cool_off_time)
        expect(error.retry_after).to eq(state_snapshot.recovery_scheduled_after)
      }
    end

    it "produces RunCompleted event" do
      expect do
        expect { result }.to raise_error(Stoplight::Error::RedLight)
      end.to emit(Stoplight::Domain::Telemetry::RunCompleted).with(
        outcome: :blocked,
        color: "red",
        duration_ms: nil,
        failure: nil,
        fallback_used: false,
        retry_after: state_snapshot.recovery_scheduled_after
      )
    end
  end
end
