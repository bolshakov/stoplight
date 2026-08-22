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

      expect(counter.sum_in_window(10)).to eq(3)
    end

    it "when empty returns zero sum" do
      at(100)
      expect(counter.sum_in_window(0)).to eq(0)
      expect(counter.sum_in_window(100)).to eq(0)
      expect(counter.sum_in_window(10000)).to eq(0)
    end

    it "increments the count for the different seconds" do
      at(98)
      counter.increment
      counter.increment
      at(99)
      counter.increment
      counter.increment
      at(100)
      counter.increment

      expect(counter.sum_in_window(2)).to eq(5)
      expect(counter.sum_in_window(1)).to eq(3)
      expect(counter.sum_in_window(0)).to eq(1)
    end

    it "increments the count for the different sparsely distributed seconds" do
      at(80)
      counter.increment
      at(90)
      counter.increment
      at(95)
      counter.increment
      at(100)

      expect(counter.sum_in_window(60)).to eq(3)
      expect(counter.sum_in_window(15)).to eq(2)
      expect(counter.sum_in_window(5)).to eq(1)
      expect(counter.sum_in_window(2)).to eq(0)
    end
  end

  describe "#sum_in_window" do
    it "returns zero when no increments in the window" do
      at(100)
      expect(counter.sum_in_window(0)).to eq(0)
    end
  end
end
