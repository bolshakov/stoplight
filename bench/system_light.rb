# frozen_string_literal: true

require "benchmark/ips"
require_relative "../lib/stoplight"
Stoplight(SecureRandom.uuid, threshold: 10)

system = Stoplight.register_system("default")

Benchmark.ips do |b|
  b.report("before") { system.register("bar", threshold: 4) }
  b.hold!("cache")
  b.report("after") { system.register("bar", threshold: 4) }

  b.compare!
end
