# coding: utf-8

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name = 'stoplight'
  spec.version = '0.1.0' # Stoplight::VERSION
  spec.summary = 'Traffic control for code.'
  spec.description = spec.summary
  spec.homepage = 'https://github.com/orgsync/stoplight'
  spec.authors = ['Cameron Desautels', 'Taylor Fausak']
  spec.email = %w(camdez@gmail.com taylor@fausak.me)
  spec.license = 'MIT'

  spec.require_path = 'lib'
  spec.test_files = Dir.glob(File.join('spec', '**', '*.rb'))
  spec.files = Dir.glob(File.join(spec.require_path, '**', '*.rb')) +
    spec.test_files + %w(CHANGELOG.md LICENSE.md README.md)

  spec.required_ruby_version = '>= 1.9.3'

  spec.add_development_dependency 'coveralls', '~> 0.7.1'
  spec.add_development_dependency 'fakeredis', '~> 0.5.0'
  spec.add_development_dependency 'rake', '~> 10.3.2'
  spec.add_development_dependency 'rspec', '~> 3.0.0'
  spec.add_development_dependency 'rubocop', '~> 0.25.0'
  spec.add_development_dependency 'yard', '~> 0.8.7.4'
end
