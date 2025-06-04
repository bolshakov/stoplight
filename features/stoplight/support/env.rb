# frozen_string_literal: true

require "stoplight"
require_relative "stoplight_world"
require_relative "configure_light_world"

Before { reset! }
After { Timecop.return }
Around do |_scenario, block|
  DatabaseCleaner.cleaning do
    block.call
  end
end

World(StoplightWorld, ConfigureLightWorld)
