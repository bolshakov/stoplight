# frozen_string_literal: true

RSpec.describe Stoplight::Infrastructure::Memory::Storage::WindowMetrics::SlidingWindow do
  subject(:counter) { described_class.new(clock:, window_size:) }

  let(:clock) { instance_double(NullClock) }
  let(:window_size) { 60 }

  # Position the monotonic clock at an absolute second.
  def at(seconds)
    allow(clock).to receive(:monotonic_time).and_return(seconds * 1000.0)
  end

  describe "#increment" do
    it "increments the count for the given time" do
      at(100)
      counter.increment
      counter.increment
      counter.increment

      expect(counter.sum_in_window).to eq(3)
    end

    it "when empty returns zero sum" do
      at(100)
      expect(counter.sum_in_window).to eq(0)
    end

    context "when events span the configured window" do
      let(:window_size) { 2 }

      it "counts events within the window" do
        at(98)
        counter.increment
        counter.increment
        at(99)
        counter.increment
        counter.increment
        at(100)
        counter.increment

        expect(counter.sum_in_window).to eq(5)
      end
    end

    context "when events are sparsely distributed" do
      let(:window_size) { 15 }

      it "expires events outside the window" do
        at(80)
        counter.increment
        at(90)
        counter.increment
        at(95)
        counter.increment
        at(100)

        expect(counter.sum_in_window).to eq(2)
      end
    end
  end

  describe "#sum_in_window" do
    it "returns zero when no increments in the window" do
      at(100)
      expect(counter.sum_in_window).to eq(0)
    end
  end
end
