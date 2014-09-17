# coding: utf-8

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name = 'stoplight'
  spec.version = '0.3.1' # Stoplight::VERSION
  spec.summary = 'Traffic control for code.'
  spec.description = spec.summary
  spec.homepage = 'http://orgsync.github.io/stoplight'
  spec.authors = ['Cameron Desautels', 'Taylor Fausak']
  spec.email = %w(camdez@gmail.com taylor@fausak.me)
  spec.license = 'MIT'

  spec.require_path = 'lib'
  spec.test_files = Dir.glob(File.join('spec', '**', '*.rb'))
  spec.files = Dir.glob(File.join(spec.require_path, '**', '*.rb')) +
    spec.test_files + %w(CHANGELOG.md LICENSE.md README.md)

  spec.required_ruby_version = '>= 1.9.3'

  spec.add_development_dependency 'benchmark-ips', '~> 2.0'
  spec.add_development_dependency 'coveralls', '~> 0.7'
  spec.add_development_dependency 'fakeredis', '~> 0.5'
  spec.add_development_dependency 'rake', '~> 10.3'
  spec.add_development_dependency 'rspec', '~> 3.1'
  spec.add_development_dependency 'rubocop', '~> 0.26'
  spec.add_development_dependency 'yard', '~> 0.8'
end
