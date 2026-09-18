# frozen_string_literal: true

require "benchmark/ips"
require_relative "../lib/stoplight"
require "redis"

redis = Redis.new
Stoplight.configure do |config|
  config.data_store = Stoplight::DataStore::Redis.new(redis)
end
cashed_stoplight = Stoplight(SecureRandom.uuid, threshold: 10)

Benchmark.ips do |b|
  b.report("after") { cashed_stoplight.run(->(_) {}) { raise if rand(11) % 10 == 1 } }
  b.hold!("redis")
  b.report("before") { cashed_stoplight.run(->(_) {}) { raise if rand(11) % 10 == 1 } }

  b.compare!
end
