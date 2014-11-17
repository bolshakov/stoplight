# coding: utf-8

Gem::Specification.new do |gem|
  gem.name = 'stoplight'
  gem.version = '0.0.0'
  gem.summary = 'Traffic control for code.'
  gem.description = 'An implementation of the circuit breaker pattern.'
  gem.homepage = 'https://github.com/orgsync/stoplight'
  gem.license = 'MIT'
  gem.authors = ['Cameron Desautels', 'Taylor Fausak', 'Justin Steffy']
  gem.email = %w(camdez@gmail.com taylor@fausak.me steffy@orgsync.com)

  gem.files = Dir.glob(File.join('lib', '**', '*.rb'))
  gem.test_files = Dir.glob(File.join('spec', '**', '*.rb'))

  gem.required_ruby_version = '>= 1.9.3'

  gem.add_development_dependency 'fakeredis', '~> 0.5'
  gem.add_development_dependency 'hipchat', '~> 1.4'
  gem.add_development_dependency 'redis', '~> 3.1'
end
