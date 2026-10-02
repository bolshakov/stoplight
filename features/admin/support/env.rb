# frozen_string_literal: true

require "stoplight"
require "stoplight/admin"
require_relative "admin_world"

Before do
  reset!
end

Around do |_scenario, block|
  DatabaseCleaner.cleaning do
    block.call
  end
end

World(AdminWorld)
