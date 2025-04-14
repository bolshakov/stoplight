# frozen_string_literal: true

require "benchmark/ips"
require "stoplight"
require "redis"

class OldRedis < Stoplight::DataStore::Redis
  # Saves a new failure to the errors HSet and cleans up outdated errors.
  def record_failure(config, failure)
    *, size = @redis.then do |client|
      client.multi do |transaction|
        failures_key = failures_key(config)

        transaction.zadd(failures_key, failure.time.to_i, failure.to_json)
        remove_outdated_failures(config, failure.time, transaction: transaction)
        transaction.zcard(failures_key)
      end
    end

    size
  end

  private

  # @param config [Stoplight::Light::Config]
  # @param time [Time]
  def remove_outdated_failures(config, time, transaction:)
    failures_key = failures_key(config)

    # Remove all errors happened before the window start
    transaction.zremrangebyscore(failures_key, 0, time.to_i - config.window_size)
    # Keep at most +config.threshold+ number of errors
    transaction.zremrangebyrank(failures_key, 0, -config.threshold - 1)
  end
end
redis = Redis.new

not_optimized_data_store = OldRedis.new(redis)
optimized_data_store = Stoplight::DataStore::Redis.new(redis)

old_redis_config = Stoplight.config_provider.provide("old-redis", data_store: not_optimized_data_store)
new_redis_config = Stoplight.config_provider.provide("new-redis", data_store: optimized_data_store)

def call_with_light(config)
  failure = Stoplight::Failure.new("class", "message", Time.new)
  config.data_store.record_failure(config, failure)
end

Benchmark.ips do |b|
  b.config(warmup: 5, time: 10)

  b.report("not optimized") { call_with_light(old_redis_config) }
  b.report("optimized") { call_with_light(new_redis_config) }

  b.compare!
end

# ruby 3.3.4 (2024-07-09 revision be1089c8ec) [arm64-darwin23]
# Warming up --------------------------------------
#        not optimized     1.292k i/100ms
#            optimized     2.214k i/100ms
# Calculating -------------------------------------
#        not optimized     16.963k (± 8.7%) i/s   (58.95 μs/i) -    167.960k in  10.033443s
#            optimized     23.439k (± 4.7%) i/s   (42.66 μs/i) -    234.684k in  10.036023s
#
# Comparison:
#            optimized:    23439.3 i/s
#        not optimized:    16963.3 i/s - 1.38x  slower
