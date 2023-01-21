# frozen_string_literal: true

module Stoplight # rubocop:disable Style/Documentation
  class << self
    # @!attribute default_data_store
    #   @return [DataStore::Base]
    attr_accessor :default_data_store

    # @!attribute default_notifiers
    #   @return [Array<Notifier::Base>]
    attr_accessor :default_notifiers

    # @!attribute default_error_notifier
    #   @return [Proc]
    attr_accessor :default_error_notifier
  end
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

module Stoplight # rubocop:disable Style/Documentation
  @default_data_store = Default::DATA_STORE
  @default_notifiers = Default::NOTIFIERS
  @default_error_notifier = Default::ERROR_NOTIFIER
end

require 'stoplight/configurable'
require 'stoplight/builder'
require 'stoplight/configuration'
require 'stoplight/light/lockable'
require 'stoplight/light/runnable'
require 'stoplight/light'

# @see Stoplight::Builder
def Stoplight(name, &code) # rubocop:disable Naming/MethodName
  if block_given?
    warn '[DEPRECATED] Calling `Stoplight("name") { ... }` with a code block is deprecated. ' \
      'Please pass code block to the run method `Stoplight("name").run { ... }` method instead.'
    Stoplight::Builder.with(name: name).build(&code)
  else
    Stoplight::Builder.with(name: name)
  end
end
