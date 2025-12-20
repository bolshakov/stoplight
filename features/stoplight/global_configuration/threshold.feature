Feature: Stoplight configuration - Threshold
  As a Ruby developer using Stoplight
  I want to set default configuration for all lights globally
  So that I don't have to repeat configuration for every light

  Scenario: Global threshold applies to newly created lights
    Given global configuration:
      | Threshold | 5 |
    When a light exists
    And the service starts failing with "timeout"
    And 4 requests are made
    Then the light color is green
    When 1 request is made
    Then the light color is red

  Scenario: Instance threshold overrides global threshold
    Given global configuration:
      | Threshold | 5 |
    When a light configured with:
      | Threshold | 2 |
    And the service starts failing with "timeout"
    And 1 request is made
    Then the light color is green
    When 1 request is made
    Then the light color is red

  @global_configuration
  Scenario: Global threshold doesn't affect already-created lights
    Given a light configured with:
      | Threshold | 3 |
    And I update global configuration:
      | Threshold | 10 |
    And the service starts failing with "timeout"
    When 2 requests are made
    Then the light color is green
    When 1 request is made
    Then the light color is red
    Given a light exists
    When 9 requests are made
    Then the light color is green
    When 1 request is made
    Then the light color is red
