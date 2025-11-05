Feature: Stoplight configuration - Cool Off Time
  As a Ruby developer using Stoplight
  I want to set default configuration for all lights globally
  So that I don't have to repeat configuration for every light

  Scenario: Global cool off time applies to newly created lights
    Given global configuration:
      | Cool Off Time | 30 |
    When a light exists
    And the service starts failing with "timeout"
    And the light enters red state
    And 28 seconds have elapsed
    Then the light color is red
    When 3 seconds have elapsed
    Then the light color is yellow

  Scenario: Instance cool off time overrides global window size
    Given global configuration:
      | Cool Off Time | 30 |
    And a light configured with:
      | Cool Off Time | 10 |
    And the service starts failing with "timeout"
    And the light enters red state
    When 11 seconds have elapsed
    Then the light color is yellow


  Scenario: Global cool off time doesn't affect already-created lights
    Given a light configured with:
      | Cool Off Time | 10 |
    And I update global configuration:
      | Cool Off Time | 30 |
    And the service starts failing with "timeout"
    And the light enters red state
    When 11 seconds have elapsed
    Then the light color is yellow

    Given a light exists
    And the light enters red state
    When 28 seconds have elapsed
    Then the light color is red
    When 3 seconds have elapsed
    Then the light color is yellow
