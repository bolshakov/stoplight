# frozen_string_literal: true

module Stoplight # rubocop:disable Style/Documentation
end

require 'stoplight/version'

require 'stoplight/color'
require 'stoplight/error'
require 'stoplight/failure'
require 'stoplight/state'

require 'stoplight/data_store'
require 'stoplight/data_store/base'
require 'stoplight/data_store/memory'
require 'stoplight/data_store/redis'

require 'stoplight/notifier'
require 'stoplight/notifier/base'
require 'stoplight/notifier/generic'

require 'stoplight/notifier/io'
require 'stoplight/notifier/logger'

require 'stoplight/default'

require 'stoplight/configuration'
require 'stoplight/light/lockable'
require 'stoplight/light/runnable'
require 'stoplight/light'

# @see Stoplight::Light#initialize
def Stoplight(name, &code) # rubocop:disable Naming/MethodName
  if block_given?
    Stoplight::Light.new(name, &code)
  else
    Stoplight::Configuration.new(name)
  end
end
