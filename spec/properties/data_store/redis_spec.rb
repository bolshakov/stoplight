require "rantly/rspec_extensions"
require "spec_helper"

RSpec.describe "Stoplight::DataStore::Redis#buckets_for_window", :redis do
  let(:light_name) { "test_circuit" }
  let(:metric) { "failures" }
  let(:bucket_size) { 3600 }

  it "properly covers entire time window" do
    # Test with random window sizes and end times
    property_of {
      window_size = range(1, 86400)  # 1 second to 24 hours
      window_end = range(0, 86400)  # 1 second to 24 hours
      [window_size, window_end]
    }.check do |window_size, window_end|
      window_end = Time.now.to_i - window_end
      window_start = window_end - window_size

      # Get buckets for this window
      buckets = Stoplight::DataStore::Redis.buckets_for_window(
        light_name, metric: metric,
        window_end: window_end,
        window_size: window_size
      )

      # Convert bucket keys back to timestamps
      bucket_timestamps = buckets.map { |bucket| bucket.split(":").last.to_i }

      # Property 1: Every bucket should be aligned to bucket boundaries
      expect(bucket_timestamps).to all(satisfy { |ts| ts % bucket_size == 0 })

      # Property 2: First bucket should cover window start
      expect(bucket_timestamps.min).to be <= window_start

      # Property 3: Last bucket should cover window end
      expect(bucket_timestamps.max + bucket_size).to be > window_end - 1

      # Property 4: No gaps between buckets
      sorted_timestamps = bucket_timestamps.sort
      gaps = sorted_timestamps.each_cons(2).map { |a, b| b - a }
      expect(gaps).to all(eq(bucket_size))
    end
  end

  it "handles edge cases with window boundaries on bucket boundaries" do
    property_of {
      # Generate timestamps exactly on bucket boundaries
      offset = range(0, 10)
      window_size = range(1, 10)
      [window_size, offset]
    }.check do |window_size, offset|
      base_ts = (Time.now.to_i / bucket_size) * bucket_size
      window_end = base_ts + offset * bucket_size
      window_size *= bucket_size

      buckets = Stoplight::DataStore::Redis.buckets_for_window(
        light_name, metric: metric,
        window_end: window_end,
        window_size: window_size
      )

      # Expected number of buckets when boundaries align perfectly
      expected_count = window_size.fdiv(bucket_size)
      expect(buckets.size).to eq(expected_count)
    end
  end

  it "returns correct number of buckets for various window sizes" do
    property_of {
      window_size = range(1, Stoplight::DataStore::Base::METRICS_RETENTION_TIME)
      window_end = Time.now.to_i
      [window_size, window_end]
    }.check do |window_size, window_end|
      buckets = Stoplight::DataStore::Redis.buckets_for_window(
        light_name, metric: metric,
        window_end: window_end,
        window_size: window_size
      )

      # Calculate expected number of buckets
      window_start_ts = window_end - window_size
      start_bucket = (window_start_ts / bucket_size) * bucket_size
      end_bucket = ((window_end - 1) / bucket_size) * bucket_size
      expected_count = ((end_bucket - start_bucket) / bucket_size) + 1

      expect(buckets.size).to eq(expected_count)
    end
  end
end
