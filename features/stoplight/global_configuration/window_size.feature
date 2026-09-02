Feature: Stoplight configuration - Window Size
  As a Ruby developer using Stoplight
  I want to set default configuration for all lights globally
  So that I don't have to repeat configuration for every light

  Scenario: Global window size applies to newly created lights
    Given global configuration:
      | Window Size | 30 |
    When a light configured with:
      | Threshold   | 3  |
    And the service starts failing with "timeout"
    And 2 requests are made
    And 31 seconds have elapsed
    When 1 request is made
    Then the light color is green

  Scenario: Instance window size overrides global window size
    Given global configuration:
      | Window Size | 30 |
    When a light configured with:
      | Threshold   | 3  |
      | Window Size | 10 |
    And the service starts failing with "timeout"
    And 2 requests are made
    And 11 seconds have elapsed
    When 1 request is made
    Then the light color is green

  @global_configuration
  Scenario: Global window size doesn't affect already-created lights
    Given a light configured with:
      | Window Size | 30 |
      | Threshold   | 3  |
    And I update global configuration:
      | Window Size | 10 |
    And the service starts failing with "timeout"
    And 2 requests are made
    And 31 seconds have elapsed
    When 1 request is made
    Then the light color is green

    When a light configured with:
      | Threshold   | 3  |
    And 2 requests are made
    And 9 seconds have elapsed
    When 1 request is made
    Then the light color is red

  Scenario: Global window size nil means no window (count all failures)
    Given global configuration:
      | Window Size | nil |
    When a light configured with:
      | Threshold   | 3  |
    And the service starts failing with "timeout"
    And 1 request is made
    And 1 hour have elapsed
    And 1 request is made
    And 1 hour have elapsed
    And 1 request is made
    Then the light color is red
