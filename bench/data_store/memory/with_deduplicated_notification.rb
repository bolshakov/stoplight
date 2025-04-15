require "benchmark"
require "stoplight"
require "concurrent-ruby"
class OriginalImplementation
  include MonitorMixin

  def initialize(...)
    @last_notifications = {}
    super
  end

  def with_deduplicated_notification(name, from_color, to_color)
    synchronize do
      if last_notification(name) != [from_color, to_color]
        set_last_notification(name, from_color, to_color)
        yield
      end
    end
  end

  def last_notification(name)
    @last_notifications[name]
  end

  def set_last_notification(name, from_color, to_color)
    @last_notifications[name] = [from_color, to_color]
  end
end

class WithYieldOutsideSync < OriginalImplementation
  def with_deduplicated_notification(name, from_color, to_color)
    notify = false
    synchronize do
      if last_notification(name) != [from_color, to_color]
        set_last_notification(name, from_color, to_color)
        notify = true
      end
    end
    yield if notify
  end
end

class WithYieldOutsideSync2 < OriginalImplementation
  def with_deduplicated_notification(name, from_color, to_color)
    synchronize do
      return if last_notification(name) == [from_color, to_color]
      set_last_notification(name, from_color, to_color)
    end
    yield
  end
end

class ConcurrentMap
  def initialize
    @last_notifications = Concurrent::Map.new do |h, k|
      h[k] = nil
    end
  end

  def with_deduplicated_notification(name, from_color, to_color)
    notify = false
    @last_notifications.compute(name) do |last_notification|
      if last_notification != [from_color, to_color]
        notify = true
        [from_color, to_color]
      else
        last_notification
      end
    end
    yield if notify
  end
end

class ConcurrentMap2
  def initialize
    @last_notifications = Concurrent::Map.new do |h, k|
      h[k] = nil
    end
  end

  def with_deduplicated_notification(name, *new_value)
    # Try to put the value if the key is absent
    last_notification = @last_notifications.put_if_absent(name, new_value)

    if last_notification.nil?
      # Key was absent, we stored the value, so notify
      yield
    elsif last_notification != new_value
      # Updates only if jey exists but value different
      if @last_notifications.replace_pair(name, last_notification, new_value)
        yield
      end
    end
  end
end

NUM_THREADS = 16
ITERATIONS = 1000

STATES = ["green", "yellow", "red"]
NAMES10 = 10.times.map { |i| "name_#{i}" }
NAMES100 = 100.times.map { |i| "name_#{i}" }

def run_concurrent_test(names, implementation)
  threads = Array.new(NUM_THREADS) do
    Thread.new do
      2_000.times do
        implementation.with_deduplicated_notification(names.sample, *STATES.sample(2)) do
          sleep 0.001
        end
      end
    end
  end
  threads.each(&:join)
end

original = OriginalImplementation.new
yield_outside = WithYieldOutsideSync.new
yield_outside2 = WithYieldOutsideSync2.new # THis implements micro-optimization
concurrent_map = ConcurrentMap.new
concurrent_map2 = ConcurrentMap2.new

pp "=== Measuring High Contention Scenario ==="
Benchmark.bm do |x|
  x.report("original             ") { run_concurrent_test(NAMES10, original) }
  x.report("yield outside sync   ") { run_concurrent_test(NAMES10, yield_outside) }
  x.report("yield outside sync 2 ") { run_concurrent_test(NAMES10, yield_outside2) }
  x.report("concurrent map       ") { run_concurrent_test(NAMES10, concurrent_map) }
  x.report("concurrent map 2     ") { run_concurrent_test(NAMES10, concurrent_map2) }
end

pp "=== Measuring Low Contention Scenario ==="
Benchmark.bm do |x|
  x.report("original             ") { run_concurrent_test(NAMES100, original) }
  x.report("yield outside sync   ") { run_concurrent_test(NAMES100, yield_outside) }
  x.report("yield outside sync 2 ") { run_concurrent_test(NAMES100, yield_outside2) }
  x.report("concurrent map       ") { run_concurrent_test(NAMES100, concurrent_map) }
  x.report("concurrent map 2     ") { run_concurrent_test(NAMES100, concurrent_map2) }
end
