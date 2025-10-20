# frozen_string_literal: true

require "benchmark/ips"
require_relative "../lib/stoplight"
require "redis"
require "connection_pool"

data_store = Stoplight::DataStore::Redis.new(Redis.new)
light = Stoplight(SecureRandom.uuid, window_size: 60, threshold: 10, data_store:)
config = light.config
#
# Benchmark.ips do |b|
#   b.config(time: 60)
#   b.report("After") { light.run(->(*) {}) { raise if rand(101) % 100 == 1 } }
#   b.hold!("hold")
#   b.report("Before") { light.run(->(*) {}) { raise if rand(101) % 100 == 1 } }
#
#   b.compare!
# end

Benchmark.ips do |b|
  b.report("After") { data_store.get_metadata(config) }
  b.hold!("hold")
  b.report("Before") { data_store.get_metadata(config) }

  b.compare!
end
