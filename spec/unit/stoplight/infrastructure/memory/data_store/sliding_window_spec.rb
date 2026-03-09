# frozen_string_literal: true

RSpec.describe Stoplight::Infrastructure::Memory::DataStore::SlidingWindow do
  let(:counter) { described_class.new(clock:) }
  let(:clock) { Stoplight::Infrastructure::SystemClock.new }

  around do |example|
    Timecop.freeze do
      example.run
    end
  end

  describe "#increment" do
    it "increments the count for the given time" do
      counter.increment
      counter.increment
      counter.increment

      expect(counter.sum_in_window(Time.now - 10)).to eq(3)
    end

    it "when empty returns zero sum" do
      expect(counter.sum_in_window(Time.now)).to eq(0)
      expect(counter.sum_in_window(Time.now - 100)).to eq(0)
      expect(counter.sum_in_window(Time.now - 10000)).to eq(0)
    end

    it "increments the count for the different seconds" do
      Timecop.freeze(Time.now - 2) do
        counter.increment
        counter.increment
      end
      Timecop.freeze(Time.now - 1) do
        counter.increment
        counter.increment
      end
      Timecop.freeze(Time.now) do
        counter.increment
      end

      expect(counter.sum_in_window(Time.now - 2)).to eq(5)
      expect(counter.sum_in_window(Time.now - 1)).to eq(3)
      expect(counter.sum_in_window(Time.now)).to eq(1)
    end

    it "increments the count for the different sparsely distributed seconds" do
      Timecop.freeze(Time.now - 20) do
        counter.increment
      end
      Timecop.freeze(Time.now - 10) do
        counter.increment
      end
      Timecop.freeze(Time.now - 5) do
        counter.increment
      end

      expect(counter.sum_in_window(Time.now - 60)).to eq(3)
      expect(counter.sum_in_window(Time.now - 15)).to eq(2)
      expect(counter.sum_in_window(Time.now - 5)).to eq(1)
      expect(counter.sum_in_window(Time.now - 2)).to eq(0)
    end
  end

  describe "#sum_in_window" do
    it "returns zero when no increments in the window" do
      expect(counter.sum_in_window(Time.now)).to eq(0)
    end
  end
end
