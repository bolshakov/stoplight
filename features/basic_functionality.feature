Feature: Stoplight Basic Functionality
  As a Ruby developer using Stoplight
  I want to use the public interface to protect services
  So that my application remains responsive when dependencies fail

  Background:
    Given a light "basic-service" exists

  Scenario: Light allows traffic in green state
    Given the protected service is functioning normally
    When I make a request to the service with "Hi! How are you?" message
    Then the light returns "Service says: Hi! How are you?"
    And its color is green

  Scenario: Light prevents traffic in red state
    Given the protected service starts failing with "connection-timeout"
    And the light enters the red state
    When I make a request to the service
    Then the light fails with error:
      | Type        | Stoplight::Error::RedLight |
      | Message     | basic-service |

  Scenario: Light count all failures regardless of time
    Given the protected service starts failing with "connection-timeout"
    When I make a request to the service
    Then the light color is green
    When 10 days elapsed
    And I make a request to the service
    Then the light color is green
    When 10 days elapsed
    And I make a request to the service
    Then the light color is red

  Scenario: Light allows one test probe (unsuccessful) in the red state
    Given the protected service starts failing with "connection-timeout"
    And the light enters the yellow state
    When I make a request to the service
    Then the light fails with error:
      | Type        | StandardError |
      | Message     | connection-timeout |
    When I make a request to the service
    Then the light fails with error:
      | Type        | Stoplight::Error::RedLight |

  Scenario: Light allows one test probe (successful) in the yellow state
    Given the protected service starts failing with "connection-timeout"
    And the light enters the yellow state
    And the protected service recovers and starts functioning normally
    When I make a request to the service with "Hi! How are you?" message
    Then the light returns "Service says: Hi! How are you?"
    When I make a request to the service with "Are you sure?" message
    Then the light returns "Service says: Are you sure?"

  Scenario: Light with fallback returns fallback value in red state
    Given the protected service starts failing with "connection-timeout"
    And the light enters the red state
    When I make a request to the service with "Hi! How are you?" message and fallback "Service temporarily unavailable"
    Then the light returns "Service temporarily unavailable"

  Scenario: Light with fallback ignores fallback value in green state
    When I make a request to the service with "Hi! How are you?" message and fallback "Service temporarily unavailable"
    Then the light returns "Service says: Hi! How are you?"

  Scenario: Light with fallback returns fallback value in case of failure in yellow state
    And the protected service starts failing with "connection-timeout"
    And the light enters the yellow state
    When I make a request to the service with "Hi! How are you?" message and fallback "Service temporarily unavailable"
    Then the light returns "Service temporarily unavailable"
