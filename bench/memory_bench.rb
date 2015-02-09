# coding: utf-8

require 'benchmark/ips'
require 'stoplight'

Benchmark.ips do |b|
  b.report('creating lambda')    { -> {} }
  b.report('calling lambda')     { -> {}.call }
  b.report('creating stoplight') { Stoplight('') {} }
  b.report('calling stoplight')  { Stoplight('') {}.run }

  b.compare!
end
