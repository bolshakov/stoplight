# frozen_string_literal: true

lib = File.expand_path('lib', File.dirname(__FILE__))
$LOAD_PATH.push(lib) unless $LOAD_PATH.include?(lib)

require 'stoplight/version'

Gem::Specification.new do |gem|
  gem.name = 'stoplight'
  gem.version = Stoplight::VERSION
  gem.summary = 'Traffic control for code.'
  gem.description = 'An implementation of the circuit breaker pattern.'
  gem.homepage = 'https://github.com/bolshakov/stoplight'
  gem.license = 'MIT'

  {
    'Cameron Desautels' => 'camdez@gmail.com',
    'Taylor Fausak' => 'taylor@fausak.me',
    'Justin Steffy' => 'steffy@orgsync.com'
  }.tap do |hash|
    gem.authors = hash.keys
    gem.email = hash.values
  end

  gem.files = %w[
    CHANGELOG.md
    LICENSE.md
    README.md
  ] + Dir.glob(File.join('lib', '**', '*.rb'))
  gem.test_files = Dir.glob(File.join('spec', '**', '*.rb'))

  gem.required_ruby_version = '>= 2.6'

  gem.add_development_dependency('benchmark-ips', '~> 2.3')
  gem.add_development_dependency('bugsnag', '~> 4.0')
  gem.add_development_dependency('fakeredis', '~> 0.5')
  gem.add_development_dependency('hipchat', '~> 1.5')
  gem.add_development_dependency('honeybadger', '~> 2.5')
  gem.add_development_dependency('pagerduty', '~> 2.1.1')
  gem.add_development_dependency('rake', '~> 13.0')
  gem.add_development_dependency('redis', '~> 3.2')
  gem.add_development_dependency('rspec', '~> 3.3')
  gem.add_development_dependency('rubocop', '~> 1.0.0')
  gem.add_development_dependency('sentry-raven', '~> 1.2')
  gem.add_development_dependency('simplecov', '~> 0.21')
  gem.add_development_dependency('simplecov-lcov', '~> 0.8')
  gem.add_development_dependency('slack-notifier', '~> 1.3')
  gem.add_development_dependency('timecop', '~> 0.8')
end
