Feature: Stoplight Custom Configuration
  As a Ruby developer using Stoplight
  I want to customize circuit breaker behavior
  So that it fits my specific service needs

  Background:
    Given a light "custom-config" exists

  Scenario: Light with custom error handler ignores specific errors
    Given the light is configured with:
      | Skipped Errors | KeyError |
    When the protected service starts failing with:
      | Type        | KeyError |
      | Message     | key not found: "foo" |
    And I make 3 requests to the protected service
    Then the light fails with error:
      | Type        | KeyError |
      | Message     | key not found: "foo" |

  Scenario: Light with custom error handler counts not ignored errors
    Given the light is configured with:
      | Skipped Errors | KeyError |
    When the protected service starts failing with "connection-timeout"
    And I make 3 requests to the protected service
    Then the light color is red

  Scenario: Light with custom threshold transitions after specified failures
    Given the light is configured with:
      | Threshold | 5 |
    When the protected service starts failing with "connection-timeout"
    And I make 4 requests to the protected service
    Then the light color is green
    And I make 1 requests to the protected service
    Then the light color is red

  Scenario: Light with custom recovery threshold recovers after specified successes
    Given the light is configured with:
      | Recovery Threshold | 5 |
    And the protected service starts failing with "connection-timeout"
    And the light enters the red state
    And 60 seconds elapsed
    And the protected service recovers and starts functioning normally
    When I make 4 requests to the protected service
    And the light color is yellow
    And I make 1 requests to the protected service
    Then the light color is green

  Scenario: Light with custom window size only counts recent failures
    Given the light is configured with:
      | Window Size | 10s |
    And the protected service starts failing with "connection-timeout"
    And I make 2 requests to the protected service
    When 11 seconds elapsed
    And I make 2 request to the protected service
    Then the light color is green
    When I make 1 request to the protected service
    Then the light color is red

  Scenario: Light with custom cool-off time recovers after specified period
    Given the light is configured with:
      | Cool Off Time | 5s |
    And the protected service starts failing with "connection-timeout"
    And the light enters red state
    When 6 seconds elapsed
    Then the light color is yellow
