# frozen_string_literal: true

require "rantly/rspec_extensions"

RSpec.describe "Stoplight::Infrastructure::Redis::Storage::WindowMetrics bucket alignment", :redis do
  let(:key_space) { Stoplight::Infrastructure::Redis::Storage::KeySpace.build(light_name:, system_name:) }
  let(:clock) { Stoplight::Infrastructure::SystemClock.new }
  let(:scripting) { Stoplight::Infrastructure::Redis::Storage::Scripting.new(redis:) }

  let(:light_name) { SecureRandom.uuid }
  let(:system_name) { SecureRandom.uuid }

  let(:metric) { "failures" }

  specify "bucket_key and buckets_for_window stay aligned" do
    property_of {
      hour_start = range(1, 100_000) * 3600
      offset = choose(0, range(1, 3599))
      window_size_in_buckets = range(1, 5)

      [hour_start + offset, window_size_in_buckets * 3600]
    }.check do |(window_end_ts, window_size)|
      metrics = Stoplight::Infrastructure::Redis::Storage::WindowMetrics.new(
        scripting:, redis:, clock:, key_space:,
        config: instance_double(Stoplight::Domain::Config, window_size:)
      )

      written_bucket = metrics.bucket_key(metric: metric, time: window_end_ts)
      scanned_buckets = metrics.buckets_for_window(metric: metric, window_end: window_end_ts)

      expect(scanned_buckets).to include(written_bucket),
        "Expected #{scanned_buckets.inspect} to include #{written_bucket.inspect}"
    end
  end
end
