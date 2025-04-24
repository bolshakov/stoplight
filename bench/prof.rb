# frozen_string_literal: true

require "ruby-prof"
require "stoplight"
require "redis"
require "fileutils"

# Create output directory
FileUtils.mkdir_p("profile_results")

# Setup Stoplight with Redis data store
redis = Redis.new
data_store = Stoplight::DataStore::Redis.new(redis)
Stoplight.default_data_store = data_store

stoplight = Stoplight("example").with_threshold(5).with_cool_off_time(60)

PROF_TYPES = {
  flat: RubyProf::FlatPrinter,
  graph: RubyProf::GraphHtmlPrinter,
  callstack: RubyProf::CallStackPrinter
}.freeze

def profile_scenario(name, measurement_mode = RubyProf::WALL_TIME)
  RubyProf.measure_mode = measurement_mode
  RubyProf.start

  yield

  result = RubyProf.stop

  PROF_TYPES.each_pair do |type, klass|
    File.open("profile_results/#{name}_#{type}.txt", "w") do |file|
      klass.new(result).print(file)
    end
  end
end

profile_scenario("success", RubyProf::PROCESS_TIME) do
  50.times do
    stoplight.run {}
  end
end

puts "Profiling complete. Results saved in profile_results/ directory."
