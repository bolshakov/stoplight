Feature: Admin Lights Overview
  As an operator responsible for a running application
  I want one page listing every light and what it is currently doing
  So that I can tell at a glance which dependencies are broken and why

  Background:
    Given an admin panel backed by a persistent data store

  Rule: The panel lists every registered light, worst first

    @wip
    Scenario: Lights are ordered red, then yellow, then green
      Given the following lights exist:
        | Name              | Color  |
        | Audit Logging     | green  |
        | Payment Gateway   | red    |
        | Social Media      | yellow |
        | Backup Service    | green  |
      When I visit the lights page
      Then the lights are listed in this order:
        | Payment Gateway |
        | Social Media    |
        | Audit Logging   |
        | Backup Service  |

    @wip
    Scenario: Lights of the same color are ordered by name
      Given the following lights exist:
        | Name            | Color |
        | Payment Gateway | red   |
        | Cache Layer     | red   |
      When I visit the lights page
      Then the lights are listed in this order:
        | Cache Layer     |
        | Payment Gateway |

    @wip
    Scenario: Each color is counted and shown as a percentage
      Given the following lights exist:
        | Name            | Color  |
        | Payment Gateway | red    |
        | Social Media    | yellow |
        | Cache Layer     | green  |
        | Backup Service  | green  |
      When I visit the lights page
      Then the counts are:
        | red    | 1 |
        | yellow | 1 |
        | green  | 2 |
      And the percentages are:
        | red    | 25 |
        | yellow | 25 |
        | green  | 50 |

    @wip
    Scenario: Percentages round up so a single light is never reported as zero percent
      Given 200 green lights exist
      And a red light "Payment Gateway" exists
      When I visit the lights page
      Then the red percentage is 1

  Rule: An empty panel explains itself rather than showing a blank page

    @wip
    Scenario: No lights are registered
      Given no lights exist
      When I visit the lights page
      Then I see "No lights found"
      And I am told to check that the admin uses the same data store as the application
      And I see no color counts

    # A system with no lights still renders - it is configured, just idle.
    @wip
    Scenario: A configured system has no lights of its own
      Given a system "Analytics" is configured
      And no lights in system "Analytics" exist
      When I visit the lights page for system "Analytics"
      Then I see "No lights found"

  Rule: A card explains the light's state in words, not just color

    @wip
    Scenario Outline: A light with no recorded error is described by its color
      Given a <color> light "checkout" exists
      When I visit the lights page
      Then the card for light "checkout" is titled "<title>"
      And its message is "<message>"
      And its comment is "<comment>"

      Examples:
        | color  | title            | message          | comment                                 |
        | yellow | Testing Recovery | Not available    | Recovery started: awaiting test traffic |
        | green  | Healthy          | No recent errors | Operating normally                      |

    @wip
    Scenario Outline: A locked light reports the override
      Given a light "checkout" exists
      And light "checkout" is locked to <color>
      When I visit the lights page
      Then the card for light "checkout" is titled "<title>"
      And its message is "<message>"
      And its comment is "<comment>"

      Examples:
        | color | title          | message                        | comment                                  |
        | red   | Locked Open    | Circuit manually locked open   | Override active - all requests blocked   |
        | green | Forced Healthy | Circuit manually locked closed | Override active - all requests processed |

    @wip
    Scenario: A red light shows its last error and counts down to recovery
      Given a light "checkout" configured with:
        | Cool Off Time | 60 seconds |
      And light "checkout" enters red state
      And light "checkout" last failed with "Timed out"
      And 5 seconds have elapsed
      When I visit the lights page
      Then the card for light "checkout" is titled "Last Error"
      And its message is "RuntimeError: Timed out"
      And its comment is "Will attempt recovery in 55 seconds"

    @wip
    Scenario: A light locked to red keeps showing its last error
      Given a red light "checkout" exists
      And light "checkout" last failed with "Timed out"
      And light "checkout" is locked to red
      When I visit the lights page
      Then the card for light "checkout" is titled "Last Error"
      And its message is "RuntimeError: Timed out"
      And its comment is "Override active - all requests blocked"

    @wip
    Scenario: A yellow light keeps showing its last error while awaiting test traffic
      Given a yellow light "checkout" exists
      And light "checkout" last failed with "Timed out"
      When I visit the lights page
      Then the card for light "checkout" is titled "Testing Recovery"
      And its message is "RuntimeError: Timed out"
      And its comment is "Recovery started: awaiting test traffic"

    @wip
    Scenario: A yellow light reports its progress towards recovery
      Given a light "checkout" configured with:
        | Recovery Threshold | 2 |
      And light "checkout" enters yellow state
      And light "checkout" last failed with "Timed out"
      And 1 request is made to light "checkout"
      When I visit the lights page
      Then the card for light "checkout" is titled "Testing Recovery"
      And its message is "RuntimeError: Timed out"
      And its comment is "Allowing limited test traffic (1 of 2 requests)"

    @wip
    Scenario: A locked light is labelled as locked
      Given a light "checkout" exists
      And light "checkout" is locked to green
      When I visit the lights page
      Then the card for light "checkout" shows "(Locked)"

  Rule: The traffic metric matches the light's traffic control strategy

    # Consecutive-errors lights have no request count, so there is no rate to report.
    @wip
    Scenario: A light using consecutive errors reports a bare count
      Given a light "checkout" configured with:
        | Traffic Control | Consecutive Errors |
      And light "checkout" has recorded 3 consecutive errors
      When I visit the lights page
      Then the card for light "checkout" shows "Consecutive failures: 3"

    @wip
    Scenario: A light using error rate reports errors, requests and a percentage
      Given a light "checkout" configured with:
        | Traffic Control | Error Rate |
      And light "checkout" has recorded 4 errors out of 412 requests
      When I visit the lights page
      Then the card for light "checkout" shows "Errors: 4 / 412 requests (1.0%)"

  Rule: Last check is the most recent thing that happened to the light

    @wip
    Scenario Outline: The most recent timestamp across all sources wins
      Given a light "checkout" exists
      And light "checkout" has recorded:
        | Last Error At            | <error>    |
        | Last Success At          | <success>  |
        | Recovery Last Success At | <recovery> |
        | Breached At              | <breached> |
      When I visit the lights page
      Then the card for light "checkout" shows a last check of "<shown>"

      Examples:
        | error   | success | recovery | breached | shown |
        | 5m ago  | 30s ago | -        | -        | 30s   |
        | 2h ago  | -       | 45s ago  | -        | 45s   |
        | -       | -       | -        | 10m ago  | 10m   |

    @wip
    Scenario: A light that has never been called shows no last check
      Given a light "checkout" exists
      And light "checkout" has never been called
      When I visit the lights page
      Then the card for light "checkout" shows no last check

  Rule: Landing on the panel root takes you somewhere useful

    @wip
    Scenario: The root redirects to the first configured system
      Given systems "Core" and "Analytics" are configured in that order
      When I visit the admin root
      Then I am redirected to the lights page for system "Core"
