# frozon_string_literal: true

module Stoplight
  module Wiring
    # Factory for internal system lights used by the Stoplight itself.
    #
    # System lights are isolated from user configuration to prevent
    # user settings from breaking the library's own circuit breakers.
    # For example, the FailSafe data store wrapper uses a system light
    # to protect against data store failures.
    #
    # @api private
    SystemLightFactory = Wiring::LightFactory.new(
      Wiring::SystemContainer.with(config: Light::SystemConfig)
    )
  end
end
