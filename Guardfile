# coding: utf-8

guard :rspec, cmd: 'bundle exec rspec' do
  watch('spec/spec_helper.rb') { 'spec' }
  watch(%r{^spec/.+_spec\.rb$})
  watch(%r{^lib/(.+)\.rb$}) { |m| "spec/#{m[1]}_spec.rb" }
end

guard :rubocop, all_on_start: false do
  watch('.rubocop.yml') { '.' }
  watch(%r{^[^/]+\.gemspec$})
  watch('Gemfile')
  watch('Rakefile')
  watch(/\.rb$/)
end
