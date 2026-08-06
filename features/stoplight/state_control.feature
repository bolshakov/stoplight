Feature: Stoplight State Control
  As a Ruby developer using Stoplight
  I want to test manual state control
  So that I can override automatic behavior when needed

  Background:
    Given a light "manual-control" configured with:
      | Threshold     | 3     |

  Scenario: Light can be manually locked to green
    Given the service starts failing with "connection-timeout"
    When I lock the light to green
    And 3 request are made
    And 1 request is made
    Then the light fails with error:
      | Message     | connection-timeout |
    And the light color is green
    When the service recovers and starts functioning normally
    And 1 request is made with "Hi! How are you?" message
    Then the light returns "Service says: Hi! How are you?"
    And the light is in "locked_green" state

  Scenario: Light can be manually locked to red
    Given the service is functioning normally
    When I lock the light to red
    And 1 request is made
    Then the light fails with error:
      | Type        | Stoplight::Error::RedLight |
      | Message     | Stoplight "manual-control" is red - network traffic stopped until recovery. |
    And the light color is red
    And the light is in "locked_red" state

  Scenario: Light can be unlocked to resume normal operation
    Given the service is functioning normally
    When I lock the light to red
    And I unlock it
    And 1 request is made with "Hi! How are you?" message
    Then the light returns "Service says: Hi! How are you?"
    And the light color is green
    And the light is in "unlocked" state
