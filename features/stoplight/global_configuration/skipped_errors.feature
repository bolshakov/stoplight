Feature: Stoplight configuration - Skipped Errors
  As a Ruby developer using Stoplight
  I want to set default configuration for all lights globally
  So that I don't have to repeat configuration for every light

  Scenario: Global skipped_errors applies to newly created lights
    Given global configuration:
      | Skipped Errors | ArgumentError |
      | Threshold      | 3             |
    When a light exists
    And the service starts failing with:
      | Type    | ArgumentError |
      | Message | bad argument  |
    And 3 requests are made
    Then the light color is green
    When the service starts failing with:
      | Type    | KeyError             |
      | Message | key not found: "foo" |
    And 3 requests are made
    Then the light color is red

  Scenario: Instance skipped_errors overrides global skipped_errors
    Given global configuration:
      | Skipped Errors | ArgumentError |
      | Threshold      | 3             |
    When a light configured with:
      | Skipped Errors | KeyError |
    When the service starts failing with:
      | Type    | ArgumentError |
      | Message | bad argument  |
    And 3 requests are made
    Then the light color is red

  Scenario: Global skipped_errors takes precedence over global tracked_errors
    Given global configuration:
      | Tracked Errors | StandardError |
      | Skipped Errors | ArgumentError |
      | Threshold      | 3 |
    When a light exists
    And the service starts failing with:
      | Type    | ArgumentError |
      | Message | bad argument  |
    And 3 requests are made
    Then the light color is green
