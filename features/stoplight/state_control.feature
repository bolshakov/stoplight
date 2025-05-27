Feature: Stoplight State Control
  As a Ruby developer using Stoplight
  I want to test manual state control
  So that I can override automatic behavior when needed

  Background:
    Given a light "manual-control" exists with:
      | Threshold     | 3     |

  Scenario: Light can be manually locked to green
    Given the protected service starts failing with "connection-timeout"
    When I lock the light to green
    And I make 3 requests to the service
    And I make a request to the service
    Then the light fails with error:
      | Message     | connection-timeout |
    And the light color is green
    When the protected service recovers and starts functioning normally
    And I make 1 request to the service with "Hi! How are you?" message
    Then the light returns "Service says: Hi! How are you?"

  Scenario: Light can be manually locked to red
    Given the protected service is functioning normally
    When I lock the light to red
    And I make 1 requests to the service
    Then the light fails with error:
      | Type        | Stoplight::Error::RedLight |
      | Message     | manual-control             |
    And the light color is red

  Scenario: Light can be unlocked to resume normal operation
    Given the protected service is functioning normally
    When I lock the light to red
    And I unlock it
    And I make 1 requests to the service with "Hi! How are you?" message
    Then the light returns "Service says: Hi! How are you?"
    And the light color is green
