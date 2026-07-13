Feature: Stoplight Custom Configuration
  As a Ruby developer using Stoplight
  I want to customize circuit breaker behavior
  So that it fits my specific service needs

  Scenario: Light with custom error handler ignores specific errors
    Given a light configured with:
      | Skipped Errors | KeyError |
    When the service starts failing with:
      | Type        | KeyError |
      | Message     | key not found: "foo" |
    And 3 requests are made
    Then the light fails with error:
      | Type        | KeyError |
      | Message     | key not found: "foo" |

  Scenario: Light with custom error handler counts not ignored errors
    Given a light configured with:
      | Skipped Errors | KeyError |
    When the service starts failing with "connection-timeout"
    And 3 requests are made
    Then the light color is red

  Scenario: Light with custom threshold transitions after specified failures
    Given a light configured with:
      | Threshold | 5 |
    When the service starts failing with "connection-timeout"
    And 4 requests are made
    Then the light color is green
    And 1 request is made
    Then the light color is red

  Scenario: Light with custom recovery threshold recovers after specified successes
    Given a light configured with:
      | Recovery Threshold | 5 |
    And the service starts failing with "connection-timeout"
    And the light enters red state
    And 60 seconds have elapsed
    And the service recovers and starts functioning normally
    And 4 requests are made
    And the light color is yellow
    And 1 request is made
    Then the light color is green

  Scenario: Light with custom window size only counts recent failures
    Given a light configured with:
      | Window Size | 10s |
    And the service starts failing with "connection-timeout"
    And 2 request is made
    When 11 seconds have elapsed
    And 2 request is made
    Then the light color is green
    When 1 request is made
    Then the light color is red

  Scenario: Light with custom cool-off time recovers after specified period
    Given a light configured with:
      | Cool Off Time | 5s |
    And the service starts failing with "connection-timeout"
    And the light enters red state
    When 6 seconds have elapsed
    Then the light color is yellow

  Scenario: Light with tracked_errors only counts specified errors
    Given a light configured with:
      | Tracked Errors | Timeout::Error,KeyError |
      | Threshold      | 1                       |
    When the service starts failing with:
      | Type        | ArgumentError |
    And 5 requests are made
    Then the light color is green
    When the service starts failing with:
      | Type        | Timeout::Error |
    And 1 request is made
    Then the light fails with error:
      | Type        | Timeout::Error |
    And the light color is red

  Scenario: Skipped errors take precedence over tracked errors
    Given a light configured with:
      | Tracked Errors | StandardError   |
      | Skipped Errors | Timeout::Error  |
      | Threshold      | 1               |
    When the service starts failing with:
      | Type        | Timeout::Error |
    And 1 request is made
    Then the light color is green

  Scenario: Per-call tracked errors replace the registered list and preserve registered skipped errors
    Given a light configured with:
      | Tracked Errors | KeyError       |
      | Skipped Errors | Timeout::Error |
      | Threshold      | 1              |
    When the service starts failing with:
      | Type | Timeout::Error |
    And 1 request is made with:
      | Tracked Errors | StandardError |
    Then the light color is green
    When the service starts failing with:
      | Type | KeyError |
    And 1 request is made with:
      | Tracked Errors | Timeout::Error |
    Then the light color is green

  Scenario: Per-call skipped errors replace the registered list and preserve registered tracked errors
    Given a light configured with:
      | Tracked Errors | StandardError  |
      | Skipped Errors | Timeout::Error |
      | Threshold      | 1              |
    When the service starts failing with:
      | Type | Timeout::Error |
    And 1 request is made with:
      | Skipped Errors | KeyError |
    Then the light color is red

  Scenario: System-level exceptions don't trigger circuit breaker
    Given a light configured with:
      | Threshold   | 1             |
    When the service starts failing with:
      | Type        | NoMemoryError |
    And 1 request is made
    Then the light fails with error:
      | Type        | NoMemoryError |
    And the light color is green
