# frozen_string_literal: true

require "redis"
require "database_cleaner/redis"

require_relative "echo_service"
require_relative "notifications"

# The StoplightWorld module provides a shared context for testing Stoplight functionality.
module StoplightWorld
  # @!attribute current_light
  #   @return [Stoplight::Light, nil] The current Stoplight instance being tested
  attr_accessor :current_light

  # @!attribute last_result
  #  @return [Object, nil] The result of the last operation performed in the Stoplight
  attr_reader :last_result

  # @!attribute last_exception
  #   @return [StandardError, nil] The last exception raised during the operation
  attr_reader :last_exception

  # Provides access to the notifications system used for testing.
  #
  # @return [Notifications] The notifications instance.
  def notifications
    @notifications ||= Notifications.new
  end

  # Provides access to the echo service used for testing.
  #
  # @return [EchoService] The echo service instance.
  def echo_service
    @echo_service ||= EchoService.new
  end

  # Captures the result of a block execution, storing the result or exception.
  #
  # @yield The block of code to execute.
  # @return [void]
  def capture_result
    @last_exception = nil
    @last_result = yield
  rescue => e
    @last_result = nil
    @last_exception = e
  end

  # Resets the state of the StoplightWorld, clearing all stored data and reinitializing
  # default configurations for Stoplight.
  #
  # @return [void]
  def reset!
    @notifications = nil
    @current_light = nil
    @echo_service = nil
    @last_exception = nil
    @last_result = nil
    Stoplight.default_data_store = case ENV.fetch("STOPLIGHT_DATA_STORE", "Memory")
    when "Memory"
      Stoplight::DataStore::Memory.new
    when "Redis"
      DatabaseCleaner[:redis].db = redis
      DatabaseCleaner.clean_with(:deletion)

      redis = Redis.new(url: ENV.fetch("STOPLIGHT_REDIS_URL", "redis://127.0.0.1:6379/0"))
      Stoplight::DataStore::Redis.new(redis)
    end
    Stoplight.default_notifiers = [TestNotifier.new(notifications)]
  end
end
