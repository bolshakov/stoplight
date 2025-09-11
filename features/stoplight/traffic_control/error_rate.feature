Feature: Error Rate Traffic Control Strategy
  As a Ruby developer using Stoplight
  I want to control when a light transitions to red state based on the error rate
  So that my application can respond appropriately to service failures

  Background:
    Given a light "basic-service" exists with:
        | Threshold       | 0.4        |
        | Window Size     | 60 seconds |
        | Traffic Control | Error Rate |

  Scenario: Light transitions to red after threshold failures
    Given I make 6 request to the protected service
    And the protected service starts failing with "connection-timeout"
    When I make 4 request to the protected service
    Then the light color is red
    And notification about transition from green to red is sent

  Scenario: Light remains green below threshold failures
    Given I make 7 request to the protected service
    And the protected service starts failing with "connection-timeout"
    When I make 3 request to the protected service
    Then the light color is green

  Scenario: Light transitions to yellow after cool-off period
    Given the protected service starts failing with "connection-timeout"
    And the light enters the red state
    When 61 seconds elapsed
    Then the light color is yellow

  Scenario: Light transitions to green after success in yellow state
    Given the protected service starts failing with "connection-timeout"
    And the light enters the yellow state
    And the protected service recovers and starts functioning normally
    When I make a request to the protected service
    Then the light color is green
    And notification about transition from yellow to green is sent

  Scenario: Light transitions to red after failure in yellow state
    Given the protected service starts failing with "connection-timeout"
    And the light enters the yellow state
    When I make 1 request to the service
    Then the light color is red
    And notification about transition from green to red is sent

  Scenario: Light does not transition to to red after successful call
    Given the protected service starts failing with "connection-timeout"
    When I make 9 requests to the protected service
    And the protected service recovers and starts functioning normally
    And I make 1 request to the protected service
    And the protected service starts failing with "connection-timeout" again
    When I make a request to the protected service
    Then the light color is red

  Scenario: Light does not evaluate requests before min request count
    Given the protected service starts failing with "connection-timeout"
    When I make 9 request to the protected service
    Then the light color is green
