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

require "stoplight/version"

require "stoplight/color"
require "stoplight/error"
require "stoplight/failure"
require "stoplight/state"

require "stoplight/data_store"
require "stoplight/data_store/base"
require "stoplight/data_store/memory"
require "stoplight/data_store/redis"

require "stoplight/notifier"
require "stoplight/notifier/base"
require "stoplight/notifier/generic"

require "stoplight/notifier/io"
require "stoplight/notifier/logger"

require "stoplight/default"

module Stoplight # rubocop:disable Style/Documentation
  @default_data_store = Default::DATA_STORE
  @default_notifiers = Default::NOTIFIERS
  @default_error_notifier = Default::ERROR_NOTIFIER
end

require "stoplight/circuit_breaker"
require "stoplight/light/config"
require "stoplight/light/configurable"
require "stoplight/light/lockable"
require "stoplight/light/runnable"
require "stoplight/light"

# Creates a new Stoplight circuit breaker with the given name and settings.
#
# @param name [String] The name of the circuit breaker.
# @param settings [Hash] Optional settings to configure the circuit breaker.
#   @option settings [Numeric] :cool_off_time The time to wait before resetting the circuit breaker.
#   @option settings [Stoplight::DataStore::Base] :data_store The data store to use for storing state.
#   @option settings [Proc] :error_notifier A proc to handle error notifications.
#   @option settings [Array<Stoplight::Notifier::Base>] :notifiers A list of notifiers to use.
#   @option settings [Numeric] :threshold The failure threshold to trip the circuit breaker.
#   @option settings [Numeric] :window_size The size of the rolling window for failure tracking.
#   @option settings [Array<StandardError>] :tracked_errors A list of errors to track.
#   @option settings [Array<Exception>] :skipped_errors A list of errors to skip.
#
# @return [Stoplight::CircuitBreaker] A new circuit breaker instance.
# @raise [ArgumentError] If an unknown option is provided in the settings.
def Stoplight(name, **settings) # rubocop:disable Naming/MethodName
  config = Stoplight::Light::Config.new(name: name, **settings)
  Stoplight::Light.new(config)
end
