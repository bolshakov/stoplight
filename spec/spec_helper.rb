# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"

require "simplecov"

require "stoplight"
require "timecop"
require "rack/test"

require_relative "support/adapters/null_clock"
require_relative "support/adapters/null_metrics_store"
require_relative "support/adapters/null_notifier"
require_relative "support/adapters/null_recovery_lock_store"
require_relative "support/adapters/null_recovery_lock_token"
require_relative "support/adapters/null_state_store"
require_relative "support/adapters/null_traffic_control"
require_relative "support/adapters/null_traffic_recovery"

require_relative "support/data_store"
require_relative "support/light/color"
require_relative "support/light/run"
require_relative "support/light/state"
require_relative "support/database_cleaner"
require_relative "support/exception_helpers"
require_relative "support/route_helpers"

Timecop.safe_mode = true

require File.expand_path("dummy/config/environment", __dir__)
require "ammeter/init"

RSpec.configure do |rspec|
  rspec.include Rack::Test::Methods
  rspec.include ExceptionHelpers
  rspec.include RouteHelpers, type: :request

  rspec.before { Stoplight.__stoplight__reset! }

  rspec.filter_run_when_matching :focus
  rspec.color = true
  rspec.disable_monkey_patching!
  rspec.order = :random
  rspec.warnings = true
end
