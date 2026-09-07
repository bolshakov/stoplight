# frozen_string_literal: true

lib = File.expand_path("lib", File.dirname(__FILE__))
$LOAD_PATH.push(lib) unless $LOAD_PATH.include?(lib)

require "stoplight/version"

Gem::Specification.new do |gem|
  gem.name = "stoplight"
  gem.version = Stoplight::VERSION
  gem.summary = "Traffic control for code."
  gem.description = "An implementation of the circuit breaker pattern."
  gem.homepage = "https://github.com/bolshakov/stoplight"
  gem.license = "MIT"
  gem.metadata = {
    "changelog_uri" => "https://github.com/bolshakov/stoplight/releases",
    "source_code_uri" => "https://github.com/bolshakov/stoplight",
    "bug_tracker_uri" => "https://github.com/bolshakov/stoplight/issues",
    "documentation_uri" => "https://github.com/bolshakov/stoplight#readme"
  }

  {
    "Tëma Bolshakov" => "tema@bolshakov.dev",
    "George Asfour" => "archmage@hey.com"
  }.tap do |hash|
    gem.authors = hash.keys
    gem.email = hash.values
  end

  gem.files = Dir.glob("lib/**/*") + Dir.glob("sig/**/*.rbs") + %w[UPGRADING.md CHANGELOG.md LICENSE.md README.md]

  gem.required_ruby_version = ">= 3.3"
  gem.add_dependency "zeitwerk"
  gem.add_dependency "concurrent-ruby"
end
