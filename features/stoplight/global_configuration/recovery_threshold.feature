Feature: Stoplight configuration - Recovery Threshold
  As a Ruby developer using Stoplight
  I want to set default configuration for all lights globally
  So that I don't have to repeat configuration for every light

  Scenario: Global recovery threshold applies to newly created lights
    Given global configuration:
      | Recovery Threshold | 3 |
    And the service starts failing with "timeout"
    When a light exists
    And the light enters yellow state
    And the service recovers and starts functioning normally
    When 2 requests are made
    Then the light color is yellow
    When 1 request is made
    Then the light color is green

  Scenario: Instance recovery threshold overrides global recovery threshold
    Given global configuration:
      | Recovery Threshold | 5 |
    When a light configured with:
      | Recovery Threshold | 2 |
    And the service starts failing with "timeout"
    And the light enters yellow state
    And the service recovers and starts functioning normally
    And 1 request is made
    Then the light color is yellow
    When 1 request is made
    Then the light color is green

  @global_configuration
  Scenario: Global threshold doesn't affect already-created lights
    Given a light configured with:
      | Recovery Threshold | 3 |
    And I update global configuration:
      | Recovery Threshold | 10 |
    And the service starts failing with "timeout"
    And the light enters yellow state
    And the service recovers and starts functioning normally
    When 2 requests are made
    Then the light color is yellow
    When 1 request is made
    Then the light color is green

    When a light exists
    And the service starts failing with "timeout"
    And the light enters yellow state
    And the service recovers and starts functioning normally
    When 9 requests are made
    Then the light color is yellow
    When 1 request is made
    Then the light color is green
