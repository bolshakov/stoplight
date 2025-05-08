# frozen_string_literal: true

# The echo service class simulates a service that can either process messages
# successfully or fail with a specified exception. It provides methods to control
# its behavior and simulate failures for testing purposes.
class EchoService
  # Initializes a new instance of the EchoService.
  # By default, the service is in a "healthy" state with no exception set.
  def initialize
    @exception = nil
  end

  # Sets the service to a "failing" state by specifying an exception to raise.
  #
  # @param exception [Exception] The exception to raise when the service is called.
  def fail_with(exception)
    @exception = exception
  end

  # Resets the service to a "healthy" state, clearing any previously set exception.
  def recover
    @exception = nil
  end

  # Simulates a service call. If the service is in a "healthy" state, it returns
  # a response message. If the service is in a "failing" state, it raises the
  # previously set exception.
  #
  # @param message [String] The message to process.
  # @return [String] The response message if the service is healthy.
  # @raise [Exception]
  def call(message)
    raise @exception unless @exception.nil?

    "Service says: #{message}"
  end
end
