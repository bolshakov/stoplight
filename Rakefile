# coding: utf-8

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'
require 'yard'

RSpec::Core::RakeTask.new
RuboCop::RakeTask.new
YARD::Rake::YardocTask.new

task default: %w(spec rubocop)
