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

  {
    "Cameron Desautels" => "camdez@gmail.com",
    "Taylor Fausak" => "taylor@fausak.me",
    "Justin Steffy" => "steffy@orgsync.com"
  }.tap do |hash|
    gem.authors = hash.keys
    gem.email = hash.values
  end

  gem.files = Dir.glob("lib/**/*") + %w[CHANGELOG.md LICENSE.md README.md]

  gem.required_ruby_version = ">= 3.2"
  gem.add_runtime_dependency "zeitwerk"
end
