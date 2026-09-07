# frozen_string_literal: true

RSpec.describe Stoplight::Infrastructure::Memory::Storage::WindowMetrics::SlidingWindow do
  subject(:counter) { described_class.new(clock:, window_size:) }

  let(:clock) { instance_double(NullClock) }
  let(:window_size) { 60 }

  # Position the monotonic clock at an absolute second.
  def at(seconds)
    allow(clock).to receive(:monotonic_seconds).and_return(seconds.to_f)
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

      it "excludes events exactly window_size seconds old, keeping the rest" do
        at(98)
        counter.increment
        counter.increment
        at(99)
        counter.increment
        counter.increment
        at(100)
        counter.increment

        expect(counter.sum_in_window).to eq(3)
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

    context "when read repeatedly within one second" do
      let(:window_size) { 2 }

      it "counts an increment made between two reads sharing a boundary" do
        at(100.0)
        counter.increment

        expect(counter.sum_in_window).to eq(1)

        at(100.4)
        counter.increment

        expect(counter.sum_in_window).to eq(2)

        at(100.9)
        expect(counter.sum_in_window).to eq(2)
      end
    end

    context "when the monotonic clock has not yet reached the window size" do
      let(:window_size) { 2 }

      it "still expires a bucket that has left the window" do
        at(0.5)
        counter.increment
        at(2.5)

        expect(counter.sum_in_window).to eq(0)
      end

      it "keeps a bucket that is still inside the window" do
        at(0.5)
        counter.increment
        at(1.5)

        expect(counter.sum_in_window).to eq(1)

        at(2.0)
        expect(counter.sum_in_window).to eq(0)
      end
    end

    context "when read repeatedly as the window slides forward" do
      let(:window_size) { 2 }

      it "drops one more bucket on each read" do
        at(100)
        counter.increment
        at(101)
        counter.increment

        expect(counter.sum_in_window).to eq(2)

        at(102)
        expect(counter.sum_in_window).to eq(1)

        at(103)
        expect(counter.sum_in_window).to eq(0)
      end
    end
  end
end
