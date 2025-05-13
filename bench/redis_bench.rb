# frozen_string_literal: true

require "benchmark/ips"
require "stoplight"
require "redis"
require "timecop"

redis = Redis.new
data_store = Stoplight::DataStore::Redis.new(redis)

# In your benchmark file
BUCKET_SIZES = [[1, 10, 60], [30, 300, 600], [60, 600, 1200]].freeze
WINDOW_SIZES = (300..3600).step(300).to_a.freeze       # 5m to 1h

results = {}

BUCKET_SIZES.each do |bucket_size_value|
  puts "=== Testing buckets: #{bucket_size_value}s ==="

  WINDOW_SIZES.each do |window_size|
    puts "Testing window_size: #{window_size}s"

    # Configure your ZSET implementation with this bucket size
    # (You might need to make bucket size configurable)

    stoplight = Stoplight(SecureRandom.uuid, window_size: window_size, data_store: data_store)

    Stoplight::DataStore::Redis.singleton_class.class_eval(<<~RUBY)
      def buckets
        #{bucket_size_value}
      end
    RUBY

    start_time = Time.at(1747129162) - window_size

    result = Benchmark.ips do |b|
      b.report("#{bucket_size_value}s buckets, #{window_size}s window") do
        Timecop.freeze(start_time + rand(window_size * 2)) do
          stoplight.run {}
        end
      end
    end

    results[[bucket_size_value, window_size]] = result.data.dig(0, :ips)
  end
end

require "json"
# Save results for plotting
File.write("hash_performance_matrix.json", results.to_json)

#
# Benchmark.ips do |b|
#   b.report("ZSET") { cashed_stoplight.run {} }
#   b.report("Hash with 1, 10, 60 buckets") { cashed_stoplight.run {} }
#   b.report("Hash with 30, 300, 3000 buckets") { cashed_stoplight.run {} }
#   b.hold!("test")
#   b.compare!
# end
