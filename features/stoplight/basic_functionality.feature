Feature: Stoplight Basic Functionality
  As a Ruby developer using Stoplight
  I want to use the public interface to protect services
  So that my application remains responsive when dependencies fail

  Background:
    Given a light "basic-service" configured with:
      | Threshold | 5 |

  Scenario: Light allows traffic in green state
    Given the service is functioning normally
    When 1 request is made with "Hi! How are you?" message
    Then the light returns "Service says: Hi! How are you?"
    And its color is green

  Scenario: Light prevents traffic in red state
    Given the service starts failing with "connection-timeout"
    And the light enters red state
    When 1 request is made
    Then the light fails with error:
      | Type        | Stoplight::Error::RedLight |
      | Message     | Stoplight "basic-service" is red - network traffic stopped until recovery. |

  Scenario: Light count all failures regardless of time
    Given the service starts failing with "connection-timeout"
    When 3 request is made
    Then the light color is green
    When 10 days have elapsed
    And 1 request is made
    Then the light color is green
    When 10 days have elapsed
    And 1 request is made
    Then the light color is red

  Scenario: Light allows one test probe (unsuccessful) in the red state
    Given the service starts failing with "connection-timeout"
    And the light enters yellow state
    When 1 request is made
    Then the light fails with error:
      | Type        | StandardError |
      | Message     | connection-timeout |
    When 1 request is made
    Then the light fails with error:
      | Type        | Stoplight::Error::RedLight |

  Scenario: Light allows one test probe (successful) in the yellow state
    Given the service starts failing with "connection-timeout"
    And the light enters yellow state
    And the service recovers and starts functioning normally
    When 1 request is made with "Hi! How are you?" message
    Then the light returns "Service says: Hi! How are you?"
    When 1 request is made with "Are you sure?" message
    Then the light returns "Service says: Are you sure?"

  Scenario: Multiple instances with same name share state
    Given the service starts failing with "timeout"
    When 4 requests is made
    Then the light color is green
    When a light "basic-service" configured with:
      | Threshold | 5 |
    When 1 request is made
    Then the light color is red
