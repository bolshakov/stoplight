# frozen_string_literal: true

require "stoplight"
require_relative "stoplight_world"
require_relative "configure_light_world"
require_relative "stoplight_assertion_helpers"

Before do
  Timecop.return
  Stoplight.__stoplight__reset!
  reset!
end

Before("@global_configuration") do
  pending("Skipping global configuration tests for systems") if ENV["STOPLIGHT_LIGHT_CREATION"] == "System#light"
end

Around do |_scenario, block|
  DatabaseCleaner.cleaning do
    block.call
  end
end

World(StoplightWorld, ConfigureLightWorld, StoplightAssertionHelpers)
