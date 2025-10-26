Feature: Stoplight configuration - Tracked Errors
  As a Ruby developer using Stoplight
  I want to set default configuration for all lights globally
  So that I don't have to repeat configuration for every light

  Scenario: Global tracked_errors applies to newly created lights
    Given global configuration:
      | Tracked Errors | Timeout::Error,KeyError |
      | Threshold      | 3                       |
    When a light exists
    And the service starts failing with:
      | Type    | ArgumentError |
      | Message | bad argument |
    And 4 requests are made
    Then the light color is green
    When the service starts failing with:
      | Type    | KeyError |
      | Message | key not found: "foo" |
    And 3 requests are made
    Then the light color is red

  Scenario: Instance tracked_errors overrides global tracked_errors
    Given global configuration:
      | Tracked Errors | Timeout::Error,KeyError |
      | Threshold      | 3                       |
    When a light configured with:
      | Tracked Errors | ArgumentError |
    When the service starts failing with:
      | Type    | KeyError             |
      | Message | key not found: "foo" |
    And 3 requests are made
    Then the light color is green
    When the service starts failing with:
      | Type    | ArgumentError |
      | Message | bad argument  |
    And 3 requests are made
    Then the light color is red
