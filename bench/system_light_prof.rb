# frozen_string_literal: true

require "ruby-prof"
require_relative "../lib/stoplight"
require "redis"
require "fileutils"

# Create output directory
FileUtils.mkdir_p("profile_results")

PROF_TYPES = {
  flat: RubyProf::FlatPrinter,
  graph: RubyProf::GraphHtmlPrinter,
  callstack: RubyProf::CallStackPrinter
}.freeze

system = Stoplight.__stoplight__system("default 2")
system.light("bar", threshold: 4)

def profile_scenario(name, &block)
  result = RubyProf::Profile.profile do
    block.call
  end

  PROF_TYPES.each_pair do |type, klass|
    File.open("profile_results/#{name}_#{type}.txt", "w") do |file|
      klass.new(result).print(file)
    end
  end
end

profile_scenario("success") do
  50.times do
    system.light("bar", threshold: 4)
  end
end

puts "Profiling complete. Results saved in profile_results/ directory."
