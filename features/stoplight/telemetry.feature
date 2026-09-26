Feature: Telemetry
  As a Ruby developer using Stoplight
  I want to subscribe to telemetry events
  So that I can observe circuit breaker activity without reaching into internals

  @global_configuration
  Scenario: Subscribing to run completion events
    Given a light "telemetry-service" configured with:
      | Threshold | 5 |
    And I subscribe to RunCompleted telemetry events
    When 1 request is made with "Hi!" message
    Then I received 1 RunCompleted telemetry event
