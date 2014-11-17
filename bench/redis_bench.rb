# coding: utf-8

require 'benchmark/ips'
require 'fakeredis'
require 'stoplight'

redis = Redis.new
data_store = Stoplight::DataStore::Redis.new(redis)
Stoplight::Light.default_data_store = data_store

Benchmark.ips do |b|
  b.report('creating lambda')    { -> {} }
  b.report('calling lambda')     { -> {}.call }
  b.report('creating stoplight') { Stoplight::Light.new('') {} }
  b.report('calling stoplight')  { Stoplight::Light.new('') {}.run }

  b.compare!
end
