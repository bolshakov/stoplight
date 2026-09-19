Feature: Admin State Control
  As an operator during an incident
  I want to pin a light open or closed, release it, or forget it entirely
  So that I can override automatic behaviour when I know something the circuit breaker does not

  Background:
    Given an admin panel backed by a persistent data store
    And a light "checkout" exists

  Rule: A light can be pinned to a color

    @wip
    Scenario: Locking a light green forces traffic through
      Given light "checkout" enters red state
      When I lock light "checkout" to green
      Then light "checkout" is in "locked_green" state
      And I am redirected to the lights page

    @wip
    Scenario: Locking a light red stops traffic
      Given light "checkout" enters green state
      When I lock light "checkout" to red
      Then light "checkout" is in "locked_red" state
      And I am redirected to the lights page

    @wip
    Scenario: Unlocking returns the light to automatic control
      Given light "checkout" is locked to red
      When I unlock light "checkout"
      Then light "checkout" is in "unlocked" state
      And I am redirected to the lights page

    # Yellow is a transitional state the breaker owns; it is not something an operator pins.
    @wip
    Scenario: No other color can be pinned
      When I lock light "checkout" to yellow
      Then the request fails with status 400
      And light "checkout" is in "unlocked" state

    @wip
    Scenario: Locking a light that does not exist
      When I lock light "does-not-exist" to green
      Then the request fails with status 404

    @wip
    Scenario: Unlocking a light that does not exist
      When I unlock light "does-not-exist"
      Then the request fails with status 404

  Rule: Bulk recovery only ever opens traffic back up

    # Deliberately asymmetric: one click can rescue every broken dependency, but no click
    # can take the whole application down.
    @wip
    Scenario: Locking all green rescues every broken light
      Given the following lights exist:
        | Name            | Color  |
        | Payment Gateway | red    |
        | Social Media    | yellow |
        | Cache Layer     | green  |
      When I lock all lights to green
      Then light "Payment Gateway" is in "locked_green" state
      And light "Social Media" is in "locked_green" state

    @wip
    Scenario: Lights that are already green are left alone
      Given a green light "Cache Layer" exists
      When I lock all lights to green
      Then light "Cache Layer" is in "unlocked" state

    @wip
    Scenario: There is no bulk lockout
      When I lock all lights to red
      Then the request fails with status 400
      And light "checkout" is unchanged

    @wip
    Scenario: Bulk recovery is scoped to the current system
      Given systems "Core" and "Analytics" are configured
      And a red light "Payment Gateway" in system "Core" exists
      And a red light "Event Ingest" in system "Analytics" exists
      When I lock all lights in system "Core" to green
      Then light "Payment Gateway" in system "Core" is in "locked_green" state
      And light "Event Ingest" in system "Analytics" is in "unlocked" state
      And its color is still red

  Rule: A light can be forgotten

    @wip
    Scenario: Removing a light discards its data and its registration
      Given light "checkout" enters red state
      When I remove light "checkout"
      And I visit the lights page
      Then I do not see light "checkout"
      And its stored metrics and state are gone

    # The only destructive action, and the only one that asks first.
    @wip
    Scenario: Removal asks for confirmation
      When I open the actions for light "checkout"
      Then the "Remove" control asks for confirmation
      And the "Lock Red" control does not ask for confirmation

    @wip
    Scenario: Removing a light that does not exist
      When I remove light "does-not-exist"
      Then the request fails with status 404

    # It is a display, not a registry - the application owns which lights exist.
    @wip
    Scenario: A removed light comes back when the application calls it again
      Given light "checkout" has been removed
      When 1 request is made to light "checkout"
      And I visit the lights page
      Then I see light "checkout"
      And its color is green
