# frozen_string_literal: true

require "monitor"
require "benchmark/ips"
require "stoplight"

class Original < Stoplight::DataStore::Memory
  def get_failures(config)
    synchronize { query_failures(config) }
  end

  def record_failure(config, failure)
    synchronize do
      light_name = config.name

      # Keep at most +config.threshold+ number of errors
      @failures[light_name] = @failures[light_name].first(config.threshold - 1)
      @failures[light_name].unshift(failure)
      # Remove all errors happened before the window start
      @failures[light_name] = query_failures(config, failure.time)
      @failures[light_name].size
    end
  end


  # @param config [Stoplight::Light::Config]
  # @return [<Stoplight::Failure>]
  def query_failures(config, time = Time.now)
    @failures[config.name].select do |failure|
      failure.time.to_i > time.to_i - config.window_size
    end
  end
end

class Original2 < Stoplight::DataStore::Memory
  def get_failures(config)
    synchronize { query_failures(config) }
  end

  def record_failure(config, failure)
    synchronize do
      light_name = config.name

      # Keep at most +config.threshold+ number of errors
      @failures[light_name] = @failures[light_name][0, config.threshold - 1]
      @failures[light_name].unshift(failure)
      # Remove all errors happened before the window start
      query_failures(config, failure.time).count
    end
  end

  # @param config [Stoplight::Light::Config]
  # @return [<Stoplight::Failure>]
  def query_failures(config, time = Time.now)
    cutoff_time = time.to_i - config.window_size

    @failures[config.name].reject! { |failure| failure.time.to_i <= cutoff_time }
    @failures[config.name]
  end
end

class Original3 < Stoplight::DataStore::Memory
  def get_failures(config)
    synchronize { query_failures(config) }
  end

  def record_failure(config, failure)
    synchronize do
      light_name = config.name

      # Keep at most +config.threshold+ number of errors
      @failures[light_name].pop while @failures[light_name].size > config.threshold + 1 # without creating a new array
      @failures[light_name].unshift(failure)

      # Remove all errors happened before the window start
      query_failures(config, failure.time).count
    end
  end

  # @param config [Stoplight::Light::Config]
  # @return [<Stoplight::Failure>]
  def query_failures(config, time = Time.now)
    cutoff_time = time.to_i - config.window_size

    @failures[config.name].reject! { |failure| failure.time.to_i <= cutoff_time }
    @failures[config.name]
  end
end

original = Original.new
original2 = Original2.new
original3 = Original3.new
CONFIG = Stoplight::Light::Config.new(name: "")

def benchmark(store)
  if rand < 0.1
    failure = Stoplight::Failure.from_error(StandardError.new("example"))
    store.record_failure(CONFIG, failure)
  else
    store.get_failures(CONFIG)
  end
end

pp "== mixed load =="

Benchmark.ips do |b|
  b.config(time: 5, warmup: 2)

  b.report("original  ") { benchmark(original) }
  b.report("original 2") { benchmark(original2) }
  b.report("original 3") { benchmark(original3) }

  b.compare!
end

def record_failure(store)
  failure = Stoplight::Failure.from_error(StandardError.new("example"))
  store.record_failure(CONFIG, failure)
end
pp "== record failure =="

Benchmark.ips do |b|
  b.config(time: 5, warmup: 2)

  b.report("original  ") { record_failure(original) }
  b.report("original 2") { record_failure(original2) }
  b.report("original 3") { record_failure(original3) }

  b.compare!
end
