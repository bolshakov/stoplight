# frozen_string_literal: true

RSpec.describe Stoplight::Domain::Strategies::GreenRunStrategy do
  subject(:strategy) do
    described_class.new(
      request_tracker:,
      run_recorder:,
      clock:
    )
  end

  let(:error_tracking_policy) { instance_double(Stoplight::Domain::ErrorTrackingPolicy) }
  let(:request_tracker) { instance_double(Stoplight::Domain::Tracker::Request) }
  let(:emitter) { TestTelemetryEmitter.new }
  let(:run_recorder) { Stoplight::Domain::Telemetry::RunRecorder.new(emitter:, color: Stoplight::Color::GREEN) }
  let(:clock) { instance_double(NullClock, monotonic_time: 1.4) }

  context "when code executes successfully" do
    subject(:result) { strategy.execute(nil, state_snapshot: nil, error_tracking_policy:, &code) }

    let(:code) { -> { "Success" } }

    it "returns result" do
      expect(request_tracker).to receive(:record_success)

      expect(result).to eq("Success")
    end

    it "produces RunCompleted event" do
      expect(request_tracker).to receive(:record_success)
      expect(clock).to receive(:monotonic_time).and_return(1.4, 2.2)

      expect { result }.to emit(Stoplight::Domain::Telemetry::RunCompleted).with(
        outcome: :success,
        color: "green",
        duration_ms: be_within(0.00001).of(0.8),
        failure: nil,
        fallback_used: false,
        retry_after: nil
      )
    end
  end

  context "when nobody is subscribed to telemetry" do
    subject(:result) { strategy.execute(nil, state_snapshot: nil, error_tracking_policy:, &code) }

    let(:code) { -> { "Success" } }
    let(:run_recorder) { instance_double(Stoplight::Domain::Telemetry::RunRecorder, subscribed?: false, record_success: nil) }

    it "does not measure duration" do
      expect(request_tracker).to receive(:record_success)
      expect(clock).not_to receive(:monotonic_time)

      expect(result).to eq("Success")
    end
  end

  context "when code fails" do
    subject(:result) { strategy.execute(fallback, state_snapshot: nil, error_tracking_policy:, &code) }

    let(:error) { StandardError.new("Test error") }
    let(:code) { -> { raise error } }
    let(:metadata) { instance_double(Stoplight::Domain::Metadata) }

    before do
      allow(error_tracking_policy).to receive(:track?).with(error).and_return(track_error)
    end

    context "when error is tracked" do
      let(:track_error) { true }

      context "when fallback is not provided" do
        let(:fallback) { nil }

        it "records failure, notify and raises the error" do
          expect(request_tracker).to receive(:record_failure).with(error)
          expect(clock).to receive(:monotonic_time).and_return(1.4, 2.2)

          expect do
            expect { result }.to raise_error(error)
          end.to emit(Stoplight::Domain::Telemetry::RunCompleted).with(
            outcome: :failure,
            color: "green",
            duration_ms: be_within(0.00001).of(0.8),
            failure: have_attributes(exception: error, tracked: true),
            fallback_used: false,
            retry_after: nil
          )
        end
      end

      context "when fallback is provided" do
        let(:fallback) do
          ->(error) {
            @error = error
            "Fallback"
          }
        end

        it "records failure, notify and returns the fallback" do
          expect(request_tracker).to receive(:record_failure).with(error)
          expect(clock).to receive(:monotonic_time).and_return(1.4, 2.2)

          expect do
            expect(result).to eq("Fallback")
          end.to emit(Stoplight::Domain::Telemetry::RunCompleted).with(
            outcome: :failure,
            color: "green",
            duration_ms: be_within(0.00001).of(0.8),
            failure: have_attributes(exception: error, tracked: true),
            fallback_used: true,
            retry_after: nil
          )

          expect(@error).to eq(error)
        end
      end
    end

    context "when error is not tracked" do
      let(:fallback) { nil }
      let(:track_error) { false }

      it "records success and raises the error" do
        expect(request_tracker).to receive(:record_success)
        expect(clock).to receive(:monotonic_time).and_return(1.4, 2.2)

        expect do
          expect { result }.to raise_error(StandardError, "Test error")
        end.to emit(Stoplight::Domain::Telemetry::RunCompleted).with(
          outcome: :success,
          color: "green",
          duration_ms: be_within(0.00001).of(0.8),
          failure: have_attributes(exception: error, tracked: false),
          fallback_used: false,
          retry_after: nil
        )
      end
    end
  end

  context "when success bookkeeping raises" do
    subject(:result) { strategy.execute(fallback, state_snapshot: nil, error_tracking_policy:, &code) }

    let(:code) { -> { "Success" } }
    let(:bookkeeping_error) { StandardError.new("metrics store unavailable") }
    let(:fallback_calls) { [] }
    let(:fallback) { ->(error) { fallback_calls << error } }

    before do
      allow(request_tracker).to receive(:record_success).and_raise(bookkeeping_error)
      allow(request_tracker).to receive(:record_failure)
      allow(error_tracking_policy).to receive(:track?).and_return(true)
    end

    it "surfaces the bookkeeping error without misreporting it as a run failure" do
      expect { result }.to raise_error(bookkeeping_error)

      expect(error_tracking_policy).not_to have_received(:track?)
      expect(request_tracker).not_to have_received(:record_failure)
      expect(fallback_calls).to be_empty
    end
  end
end
