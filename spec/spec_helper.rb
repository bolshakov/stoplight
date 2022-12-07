# frozen_string_literal: true

require 'simplecov'

require 'stoplight'
require 'timecop'
require_relative 'support/data_store/base'

Timecop.safe_mode = true

RSpec.configure do |rspec|
  rspec.color = true
  rspec.disable_monkey_patching!
  rspec.order = :random
  rspec.warnings = true
end
