Feature: Fallback Behavior
  As a Ruby developer using Stoplight
  I want to provide a fallback behavior to
  a service under Stoplight protection.

  Background:
    Given a light "custom-config" exists

  Scenario: Fallback is ignored when light is green
    Given the light color is green
    When 1 request is made with "Hi! How are you?" message and fallback "Service temporarily unavailable"
    Then the light returns "Service says: Hi! How are you?"

  Scenario: Fallback receives error when light is green but call fails
    Given the light color is green
    Given the service starts failing with:
      | Type        | KeyError             |
      | Message     | key not found: "foo" |
    When 1 request is made with "Hi! How are you?" message and fallback "Service temporarily unavailable"
    Then the light returns "Service temporarily unavailable"
    And the fallback have received an error:
      | Type        | KeyError             |
      | Message     | key not found: "foo" |

  Scenario: Fallback in yellow state with error
    And the service starts failing with:
      | Type        | KeyError             |
      | Message     | key not found: "foo" |
    And the light enters yellow state
    When 1 request is made with "Hi! How are you?" message and fallback "Service temporarily unavailable"
    Then the light returns "Service temporarily unavailable"
    And the fallback have received an error:
      | Type        | KeyError             |
      | Message     | key not found: "foo" |

  Scenario: Fallback receives nil when light is red
    Given the service starts failing with "connection error"
    And the light enters red state
    When 1 request is made with "Hi! How are you?" message and fallback "Service temporarily unavailable"
    Then the light returns "Service temporarily unavailable"
    And the fallback have received nil argument
