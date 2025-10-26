Feature: Consecutive Errors Traffic Control Strategy
  As a Ruby developer using Stoplight
  I want to control when a light transitions recovers from the red state
  So that my application can respond appropriately to service failures

  Background:
    Given a light "basic-service" configured with:
      | Recovery Threshold | 3 |
      | Cool Off Time     | 60 |
    And the service starts failing with "connection-timeout"
    And the light enters red state
    And 60 seconds have elapsed

  Scenario: Light transitions to green after recover threshold successes
    When the service recovers and starts functioning normally
    And 3 requests are made
    Then the light color is green
    And notification about transition from yellow to green is sent

  Scenario: Light remains yellow below recovery threshold successes
    When the service recovers and starts functioning normally
    And 2 requests are made
    Then the light color is yellow
    And notification about transition from red to yellow is sent

  Scenario: Light returns to red after failure in yellow state
    Given the service recovers and starts functioning normally
    And 1 request is made
    When the service starts failing with "connection-timeout" again
    Then the light color is yellow
    And 1 request is made
    Then the light color is red
    And notification about transition from yellow to red is sent
