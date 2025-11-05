Feature: Stoplight configuration - Traffic Control
  As a Ruby developer using Stoplight
  I want to set default configuration for all lights globally
  So that I don't have to repeat configuration for every light

  Scenario: Global traffic control consecutive_errors applies to newly created lights
    Given global configuration:
      | Traffic Control | Consecutive Errors |
      | Threshold       | 3                  |
    When a light exists
    When the service starts failing with "timeout"
    And 2 requests are made
    Then the light color is green
    When 1 request is made
    Then the light color is red

  Scenario: Global traffic control error_rate applies to newly created lights
    Given global configuration:
      | Traffic Control | Error Rate |
      | Threshold       | 0.5        |
      | Window Size     | 60         |
    When a light exists
    And 10 requests are made
    Then the light color is green
    When the service starts failing with "timeout"
    And 9 requests are made
    Then the light color is green
    When 1 request is made
    Then the light color is red

  Scenario: Instance traffic control overrides global traffic control
    Given global configuration:
      | Traffic Control | Error Rate |
      | Threshold       | 0.5        |
      | Window Size     | 60         |
    When a light configured with:
      | Traffic Control | Consecutive Errors |
      | Threshold       | 3                  |
    And the service starts failing with "timeout"
    And 2 requests are made
    Then the light color is green
    When 1 request is made
    Then the light color is red
