# frozen_string_literal: true

require "benchmark/ips"
require "stoplight"
cashed_stoplight = Stoplight("")

Benchmark.ips do |b|
  b.report("creating lambda") { -> {} }
  b.report("calling lambda") { -> {}.call }
  b.report("creating stoplight") { Stoplight("") }
  b.report("calling stoplight") { Stoplight("").run {} }
  b.report("calling cached_stoplight") { cashed_stoplight.run {} }

  b.compare!
end
