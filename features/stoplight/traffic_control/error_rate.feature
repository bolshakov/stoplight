Feature: Error Rate Traffic Control Strategy
  As a Ruby developer using Stoplight
  I want to control when a light transitions to red state based on the error rate
  So that my application can respond appropriately to service failures

  Background:
    Given a light configured with:
        | Threshold          | 0.4        |
        | Window Size        | 60 seconds |
        | Cool Off Time      | 10 seconds |
        | Traffic Control    | Error Rate |
        | Recovery Threshold | 2          |

  Scenario: Light transitions to red after threshold failures
    Given 6 request are made
    And the service starts failing with "connection-timeout"
    When 4 requests are made
    Then the light color is red
    And notification about transition from green to red is sent

  Scenario: Light remains green below threshold failures
    Given 7 request are made
    And the service starts failing with "connection-timeout"
    When 3 requests are made
    Then the light color is green

  Scenario: Light transitions to yellow after cool-off period
    Given the service starts failing with "connection-timeout"
    And the light enters red state
    When 11 seconds have elapsed
    Then the light color is yellow
    And the service recovers and starts functioning normally
    When 1 request is made
    And notification about transition from red to yellow is sent
    And the light color is yellow

  Scenario: Light does not see previous failures after cool-off period
    Given the service starts failing with "connection-timeout"
    And the light enters yellow state
    And the service recovers and starts functioning normally
    When the light enters green state
    And the service starts failing with "connection-timeout"
    And 1 request is made
    Then the light color is green

  Scenario: Light transitions to green after success in yellow state
    Given the service starts failing with "connection-timeout"
    And the light enters yellow state
    And the service recovers and starts functioning normally
    When 2 requests are made
    Then the light color is green
    And notification about transition from yellow to green is sent

  Scenario: Light transitions to red after failure in yellow state
    Given the service starts failing with "connection-timeout"
    And the light enters red state
    Then notification about transition from green to red is sent
    And the light enters yellow state
    When 1 request is made
    Then the light color is red
    And notification about transition from yellow to red is sent

  Scenario: Light does not transition to to red after successful call
    Given the service starts failing with "connection-timeout"
    When 9 requests are made
    And the service recovers and starts functioning normally
    And 1 request is made
    And the service starts failing with "connection-timeout" again
    When 1 request is made
    Then the light color is red

  Scenario: Light does not evaluate requests before min request count
    Given the service starts failing with "connection-timeout"
    When 9 requests are made
    Then the light color is green
