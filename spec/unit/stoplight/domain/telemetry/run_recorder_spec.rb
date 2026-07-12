# frozen_string_literal: true

RSpec.describe Stoplight::Domain::Telemetry::RunRecorder do
  subject(:run_recorder) { described_class.new(emitter:, color: Stoplight::Color::GREEN) }

  let(:emitter) { TestTelemetryEmitter.new }

  describe "#subscribed?" do
    let(:emitter) { instance_double(Stoplight::Domain::Telemetry::Emitter) }

    it "delegates to the emitter for RunCompleted" do
      allow(emitter).to receive(:subscribed?).with(Stoplight::Domain::Telemetry::RunCompleted).and_return(true)

      expect(run_recorder).to be_subscribed
    end
  end

  describe "#record_success" do
    it "emits a success event for the recorder's color" do
      expect { run_recorder.record_success(duration_ms: 1.2) }.to emit(Stoplight::Domain::Telemetry::RunCompleted).with(
        outcome: :success,
        color: "green",
        duration_ms: 1.2,
        failure: nil,
        fallback_used: false,
        retry_after: nil
      )
    end

    it "attaches an untracked failure when given an error" do
      error = StandardError.new("boom")

      expect do
        run_recorder.record_success(duration_ms: 1.2, error:)
      end.to emit(Stoplight::Domain::Telemetry::RunCompleted).with(
        outcome: :success,
        color: "green",
        duration_ms: 1.2,
        failure: have_attributes(exception: error, tracked: false),
        fallback_used: false,
        retry_after: nil
      )
    end
  end

  describe "#record_failure" do
    it "emits a failure event" do
      error = StandardError.new("boom")

      expect do
        run_recorder.record_failure(error, duration_ms: 1.2, fallback_used: true)
      end.to emit(Stoplight::Domain::Telemetry::RunCompleted).with(
        outcome: :failure,
        color: "green",
        duration_ms: 1.2,
        failure: have_attributes(exception: error, tracked: true),
        fallback_used: true,
        retry_after: nil
      )
    end
  end

  describe "#record_blocked" do
    it "emits a blocked event" do
      retry_after = Time.now

      expect do
        run_recorder.record_blocked(fallback_used: false, retry_after:)
      end.to emit(Stoplight::Domain::Telemetry::RunCompleted).with(
        outcome: :blocked,
        color: "green",
        duration_ms: nil,
        failure: nil,
        fallback_used: false,
        retry_after:
      )
    end
  end
end
