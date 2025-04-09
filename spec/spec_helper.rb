# frozen_string_literal: true

require 'simplecov'

require 'stoplight'
require 'timecop'
require_relative 'support/data_store/base'
require_relative 'support/light/runnable'
require_relative 'support/light/configurable'
require_relative 'support/database_cleaner'
require_relative 'support/exception_helpers'

Timecop.safe_mode = true

RSpec.configure do |rspec|
  rspec.include ExceptionHelpers

  rspec.filter_run focus: true
  rspec.color = true
  rspec.disable_monkey_patching!
  rspec.order = :random
  rspec.warnings = true
end
