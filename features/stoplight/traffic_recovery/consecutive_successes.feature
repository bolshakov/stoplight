Feature: Consecutive Errors Traffic Control Strategy
  As a Ruby developer using Stoplight
  I want to control when a light transitions recovers from the red state
  So that my application can respond appropriately to service failures

  Background:
    Given a light "basic-service" exists with:
      | Recovery Threshold | 3 |
      | Cool Off Time     | 60 |
    And the protected service starts failing with "connection-timeout"
    And the light enters the red state
    And 60 seconds elapsed

  Scenario: Light transitions to green after recover threshold successes
    When the protected service recovers and starts functioning normally
    And I make 3 request to the protected service
    Then the light color is green
    And notification about transition from yellow to green is sent

  Scenario: Light remains yellow below recovery threshold successes
    When the protected service recovers and starts functioning normally
    And I make 2 request to the protected service
    Then the light color is yellow
    And notification about transition from red to yellow is sent

  Scenario: Light returns to red after failure in yellow state
    Given the protected service recovers and starts functioning normally
    And I make 1 request to the protected service
    When the protected service starts failing with "connection-timeout" again
    Then the light color is yellow
    And I make 1 request to the protected service
    Then the light color is red
    And notification about transition from yellow to red is sent
