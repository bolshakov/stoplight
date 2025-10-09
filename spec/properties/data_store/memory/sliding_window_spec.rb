# frozen_string_literal: true

require "rantly/rspec_extensions"
require "spec_helper"

RSpec.describe Stoplight::DataStore::Memory::SlidingWindow do
  let(:counter) { Stoplight::DataStore::Memory::SlidingWindow.new }

  describe "monotonicity" do
    around do |example|
      Timecop.freeze do
        example.run
      end
    end

    it "never decreases sum when adding increments" do
      property_of {
        array(range(10, 50)) { range(0, 1000) }
      }.check do |offsets|
        counter = Stoplight::DataStore::Memory::SlidingWindow.new
        previous_sum = 0
        start_time = current_time = Time.now - offsets.sum
        offsets.each do |ts|
          Timecop.freeze(current_time += ts) do
            counter.increment
            current_sum = counter.sum_in_window(start_time)

            expect(current_sum).to be >= previous_sum,
              "Sum decreased after increment at #{ts}: #{previous_sum} -> #{current_sum}"

            previous_sum = current_sum
          end
        end
      end
    end

    it "never decreases sum when expanding the window" do
      property_of {
        [
          array(range(100, 300)) { range(0, 5) },
          array(range(5, 15)) { [range(100, 300), range(0, 100)] }
        ]
      }.check do |offsets, windows|
        counter = Stoplight::DataStore::Memory::SlidingWindow.new
        current_time = Time.now - offsets.sum
        offsets.each do |ts|
          Timecop.freeze(current_time += ts) do
            counter.increment
          end
        end

        windows.each do |cutoff1, cutoff2|
          earlier_cutoff = Time.now - cutoff1 - cutoff2
          later_cutoff = Time.now - cutoff2
          sum_with_smaller_window = counter.sum_in_window(later_cutoff)
          sum_with_larger_window = counter.sum_in_window(earlier_cutoff)

          expect(sum_with_larger_window).to be >= sum_with_smaller_window,
            "Sum decreased when expanding window from #{later_cutoff} to #{earlier_cutoff}"
        end
      end
    end
  end

  describe "additivity and partitioning" do
    it "sum equals count of all increments within window" do
      property_of {
        array(range(100, 300)) { range(0, 5) }
      }.check do |offsets|
        counter = Stoplight::DataStore::Memory::SlidingWindow.new
        start_time = current_time = Time.now - offsets.sum
        offsets.each do |ts|
          Timecop.freeze(current_time += ts) do
            counter.increment
          end
        end

        expect(counter.sum_in_window(start_time)).to eq(offsets.size)
      end
    end

    it "partitioning by cutoff produces correct sub-sums" do
      property_of {
        offsets = array(range(100, 300)) { range(0, 5) }
        partition_point = range(0, offsets.sum)
        [offsets, partition_point]
      }.check do |offsets, partition_point|
        counter = Stoplight::DataStore::Memory::SlidingWindow.new
        start_time = current_time = Time.now - offsets.sum
        offsets.each do |ts|
          Timecop.freeze(current_time += ts) do
            counter.increment
          end
        end
        # Count how many timestamps are >= partition_point
        current_time = start_time
        expected_count = offsets.count do |ts|
          (current_time += ts) >= partition_point
        end

        expect(counter.sum_in_window(start_time - partition_point)).to eq(expected_count)
      end
    end
  end

  describe "order independence" do
    it "produces same result regardless of increment order" do
      property_of {
        array(range(300, 500)) { range(0, 5) }
      }.check do |offsets|
        counter1 = Stoplight::DataStore::Memory::SlidingWindow.new
        counter2 = Stoplight::DataStore::Memory::SlidingWindow.new

        start_time = current_time = Time.now - offsets.sum

        # Add in original order
        offsets.each do |ts|
          Timecop.freeze(current_time += ts) do
            counter1.increment
          end
        end

        # Add in shuffled order
        current_time = start_time
        offsets.shuffle.each do |ts|
          Timecop.freeze(current_time += ts) do
            counter2.increment
          end
        end

        # Test multiple cutoff points
        expect(counter1.sum_in_window(start_time)).to eq(counter2.sum_in_window(start_time)),
          "Different sums for cutoff #{start_time} with different increment orders"
      end
    end
  end

  describe "boundary conditions" do
    it "cutoff at exact timestamp should include that timestamp" do
      property_of {
        array(range(5, 20)) { range(0, 100) }
      }.check do |offsets|
        counter = Stoplight::DataStore::Memory::SlidingWindow.new

        # Add increments at specific offsets from base
        times = offsets[1..].reduce([Time.now - offsets.sum]) do |acc, offset|
          acc << acc.last + offset
        end
        times.each do |time|
          Timecop.freeze(time) do
            counter.increment
          end
        end
        boundary, offset = times.sample

        count_at_boundary = counter.sum_in_window(boundary)
        count_after_boundary = counter.sum_in_window(boundary + 1)

        expect(count_at_boundary).to be > count_after_boundary,
          "Boundary at #{boundary} (offset=#{offset}) should include the increment at that timestamp"
      end
    end

    it "handles empty results correctly for future cutoffs" do
      property_of {
        offsets = array(range(10, 30)) { range(0, 100) }
        future_cutoff = range(1, 1000)
        [offsets, future_cutoff]
      }.check do |offsets, future_cutoff|
        counter = Stoplight::DataStore::Memory::SlidingWindow.new

        # Add increments at specific offsets from base
        times = offsets.reduce([Time.now - offsets.sum]) do |acc, offset|
          acc << (acc.last + offset)
        end
        times.each do |time|
          Timecop.freeze(time) do
            counter.increment
          end
        end

        expect(counter.sum_in_window(Time.now + future_cutoff)).to eq(0)
      end
    end
  end

  describe "sparse data handling" do
    it "correctly sums regardless of timestamp sparsity" do
      property_of {
        # Generate timestamps with intentional large gaps
        array(range(5, 15)) { range(0, 1_000_000) }
      }.check do |offsets|
        counter = Stoplight::DataStore::Memory::SlidingWindow.new

        start_time = Time.now - offsets.sum
        times = offsets.reduce([start_time]) do |acc, offset|
          acc << (acc.last + offset)
        end
        times.each do |time|
          Timecop.freeze(time) do
            counter.increment
          end
        end
        expect(counter.sum_in_window(start_time)).to eq(times.count)

        [900_000, 500_000, 10_000, 100].each do |cutoff|
          cutoff_time = Time.now - cutoff
          expected = times.count { |time| time >= cutoff_time }
          expect(counter.sum_in_window(Time.now - cutoff)).to eq(expected)
        end
      end
    end

    it "handles duplicate timestamps correctly" do
      property_of {
        offsets = array(range(5, 15)) { range(0, 5) }
        duplication_factor = range(1, 5)
        [offsets, duplication_factor]
      }.check do |offsets, duplication_factor|
        counter = Stoplight::DataStore::Memory::SlidingWindow.new

        # Add each offset multiple times
        start_time = Time.now - offsets.sum
        times = offsets.reduce([start_time]) do |acc, offset|
          acc.concat([acc.last + offset] * duplication_factor)
        end
        times.each do |time|
          Timecop.freeze(time) do
            counter.increment
          end
        end

        # Should count all increments
        expect(counter.sum_in_window(start_time)).to eq(times.count)

        # Pick a timestamp and verify count
        cutoff_time = times.sample
        expected = times.count { |time| time >= cutoff_time }
        expect(counter.sum_in_window(cutoff_time)).to eq(expected)
      end
    end
  end
end
