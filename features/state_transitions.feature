Feature: Stoplight State Transitions
  As a Ruby developer using Stoplight
  I want to manage the state of a light based on service health
  So that my application can respond appropriately to service failures

  Background:
    Given a light "basic-service" exists

  Scenario: Light transitions to red after threshold failures
    Given the protected service starts failing with "connection-timeout"
    When I make 3 request to the protected service
    Then the light color is red
    And notification about transition from green to red is sent

  Scenario: Light remains green below threshold failures
    Given the protected service starts failing with "connection-timeout"
    When I make 1 request to the protected service
    And the protected service recovers and starts functioning normally
    And I make 1 request to the service
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
    And notification about transition from red to green is sent

  Scenario: Light transitions to red after failure in yellow state
    Given the protected service starts failing with "connection-timeout"
    And the light enters the yellow state
    When I make 1 request to the service
    Then the light color is red
    And notification about transition from green to red is sent

  Scenario: Light resets failure count after success
    Given the protected service starts failing with "connection-timeout"
    When I make 2 requests to the protected service
    And the protected service recovers and starts functioning normally
    And I make a request to the protected service
    And the protected service starts failing with "connection-timeout" again
    When I make a request to the protected service
    Then the light color is green
