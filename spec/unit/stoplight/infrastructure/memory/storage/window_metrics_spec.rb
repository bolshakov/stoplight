# frozen_string_literal: true

require_relative "../../data_store/window_metrics_snapshot"

RSpec.describe Stoplight::Infrastructure::Memory::Storage::WindowMetrics do
  subject(:metrics) { described_class.new(window_size:, clock:) }

  let(:clock) { Stoplight::Infrastructure::SystemClock.new }
  let(:window_size) { 300 }

  it_behaves_like "a window metrics snapshot" do
    def metrics_snapshot = metrics.metrics_snapshot
    def record_failure(error) = metrics.record_failure(error)
    def record_success = metrics.record_success
  end

  describe "#record_success" do
    let(:clock) { instance_double(NullClock) }

    it "reads each clock once" do
      expect(clock).to receive(:current_time).once.and_return(Time.utc(2026, 8, 7))
      expect(clock).to receive(:monotonic_time).once.and_return(1_000.0)

      metrics.record_success
    end
  end

  describe "#record_failure" do
    let(:clock) { instance_double(NullClock) }
    let(:current_time) { Time.utc(2026, 8, 7) }

    it "reads the wall clock once and uses it for the failure" do
      expect(clock).to receive(:current_time).once.and_return(current_time)
      allow(clock).to receive(:monotonic_time).and_return(1_000.0)

      snapshot = metrics.record_failure(StandardError.new)

      expect(snapshot.last_error).to have_attributes(occurred_at: current_time)
    end
  end

  describe "#metrics_snapshot" do
    context "when the wall clock steps backwards between recordings" do
      let(:clock) { instance_double(NullClock) }
      let(:window_size) { 60 }

      it "expires events by elapsed time, not wall time" do
        t0 = Time.utc(2026, 8, 7, 12, 0, 0)
        mono = 1_000.0
        allow(clock).to receive(:monotonic_time) { mono }
        allow(clock).to receive(:current_time).and_return(t0, t0 - 300)

        metrics.record_failure(StandardError.new)
        mono = 31_000.0
        metrics.record_failure(StandardError.new)
        mono = 62_000.0

        expect(metrics.metrics_snapshot.errors).to eq(1)
      end
    end
  end
end
