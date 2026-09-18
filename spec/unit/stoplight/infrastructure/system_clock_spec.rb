# frozen_string_literal: true

RSpec.describe Stoplight::Infrastructure::SystemClock do
  subject(:clock) { described_class.new }

  describe "#current_time" do
    subject(:current_time) { clock.current_time }

    around do |example|
      Stoplight::TimeTravel.freeze { example.run }
    end

    it "returns current wall-clock time" do
      expect(current_time).to eq(Time.now)
    end
  end

  describe "#monotonic_millis" do
    subject(:monotonic_millis) { clock.monotonic_millis }

    it "returns monotonic time in milliseconds" do
      expect(monotonic_millis).to be_within(10).of(Process.clock_gettime(Process::CLOCK_MONOTONIC, :float_millisecond))
    end
  end

  describe "#monotonic_seconds" do
    subject(:monotonic_seconds) { clock.monotonic_seconds }

    it "returns monotonic time in seconds" do
      expect(monotonic_seconds).to be_within(1).of(Process.clock_gettime(Process::CLOCK_MONOTONIC, :float_second))
    end
  end

  describe "#at" do
    subject(:at) { clock.at(timestamp) }

    context "with integer timestamp" do
      let(:timestamp) { 1705329000 }

      it "converts to Time" do
        expect(at).to eq(Time.at(timestamp))
      end
    end

    context "with float timestamp (sub-second precision)" do
      let(:timestamp) { 1705329000.123456 }

      it "preserves sub-second precision" do
        expect(at.nsec).to be > 0
      end
    end

    context "with zero timestamp (Unix epoch)" do
      let(:timestamp) { 0 }

      it "returns epoch time" do
        expect(at.utc).to eq(Time.utc(1970, 1, 1))
      end
    end
  end
end
