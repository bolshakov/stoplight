# frozen_string_literal: true

require File.expand_path("../boot", __FILE__)

require "rails"
require "action_controller/railtie"

Bundler.require(*Rails.groups)

module Dummy
  class Application < Rails::Application
    config.eager_load = false

    config.load_defaults "#{Rails::VERSION::MAJOR}.#{Rails::VERSION::MINOR}"
  end
end
