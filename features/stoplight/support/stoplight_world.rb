# frozen_string_literal: true

require "redis"
require "database_cleaner/redis"

require_relative "echo_service"
require_relative "notifications"

# The StoplightWorld module provides a shared context for testing Stoplight functionality.
module StoplightWorld
  # Provides access to the notifications system used for testing.
  #
  # @return [Notifications] The notifications instance.
  attr_reader :notifications

  # @!attribute current_light
  #   @return [Stoplight::Light, nil] The current Stoplight instance being tested
  attr_accessor :current_light

  # @!attribute last_result
  #  @return [Object, nil] The result of the last operation performed in the Stoplight
  attr_reader :last_result

  # @!attribute last_exception
  #   @return [StandardError, nil] The last exception raised during the operation
  attr_reader :last_exception

  # @!attribute last_fallback_received_argument
  #   @return [any] the last argument received by a fallback function
  attr_accessor :last_fallback_received_argument

  # @!attribute received_telemetry_events
  #   @return [Array<Stoplight::Domain::Telemetry::Envelope>] events captured by scenario telemetry subscriptions
  attr_reader :received_telemetry_events

  # Provides access to the echo service used for testing.
  #
  # @return [EchoService] The echo service instance.
  attr_reader :echo_service

  # Captures the result of a block execution, storing the result or exception.
  #
  # @yield The block of code to execute.
  # @return [void]
  def capture_result
    @last_exception = nil
    @last_result = yield
  rescue Exception => e # rubocop:disable Lint/RescueException
    @last_result = nil
    @last_exception = e
  end

  # Resets the state of the StoplightWorld, clearing all stored data and reinitializing
  # default configurations for Stoplight.
  #
  # @return [void]
  def reset!
    @system = nil
    @notifications = Notifications.new
    @current_light = nil
    @echo_service = EchoService.new
    @last_exception = nil
    @last_result = nil
    @last_fallback_received_argument = :nothing
    @received_telemetry_events = []
    Stoplight.configure(trust_me_im_an_engineer: true) do |config|
      config.data_store = case ENV.fetch("STOPLIGHT_DATA_STORE", "Memory")
      when "Memory"
        Stoplight::DataStore::Memory.new
      when "Redis"
        redis = Redis.new(url: ENV.fetch("STOPLIGHT_REDIS_URL", "redis://127.0.0.1:6379/0"))

        DatabaseCleaner[:redis].db = redis
        DatabaseCleaner.clean_with(:deletion)
        Stoplight::DataStore::Redis.new(redis)
      else
        raise ArgumentError, "unexpected data store"
      end
      config.notifiers = [TestNotifier.new(notifications)]
    end
  end

  def system = @system ||= Stoplight.register_system(SecureRandom.uuid)
end
