Feature: Admin Systems
  As an operator of an application whose lights live in more than one data store
  I want each group of lights presented and acted on separately
  So that I never read one system's health as another's, or act on the wrong one

  Background:
    Given an admin panel backed by a persistent data store

  Rule: With no systems configured, the default one is used

    @wip
    Scenario: A single implicit system
      Given no systems are configured
      When I visit the admin root
      Then I am redirected to the lights page for the default system
      And no system switcher is shown

  Rule: Configured systems replace the default rather than joining it

    @wip
    Scenario: Explicit systems are the only ones shown
      Given systems "Core" and "Analytics" are configured
      When I visit the admin root
      Then I am redirected to the lights page for system "Core"
      And the system switcher offers systems "Core" and "Analytics"
      And the system switcher does not offer the default system

    @wip
    Scenario: The switcher appears only when there is a choice to make
      Given a system "Core" is configured
      When I visit the lights page for system "Core"
      Then no system switcher is shown

  Rule: Every page and every action is scoped to one system

    Background:
      Given systems "Core" and "Analytics" are configured
      And the following lights in system "Core" exist:
        | Name            | Color |
        | Payment Gateway | red   |
      And the following lights in system "Analytics" exist:
        | Name         | Color |
        | Event Ingest | green |

    @wip
    Scenario: A system's page shows only its own lights
      When I visit the lights page for system "Core"
      Then I see light "Payment Gateway"
      And I do not see light "Event Ingest"

    @wip
    Scenario: Counts are per system, not global
      When I visit the lights page for system "Analytics"
      Then the counts are:
        | red    | 0 |
        | yellow | 0 |
        | green  | 1 |

    @wip
    Scenario: The same light name in two systems is two lights
      Given a red light "cache" in system "Core" exists
      And a green light "cache" in system "Analytics" exists
      When I lock light "cache" in system "Core" to red
      Then light "cache" in system "Analytics" is in "unlocked" state
      And its color is still green

    @wip
    Scenario: An unknown system is a 404
      When I visit the lights page for system "nonexistent"
      Then the request fails with status 404

  Rule: A light's own configuration overrides its system's

    # The admin shows what the light actually runs with, not the system default.
    @wip
    Scenario: Per-light overrides are applied on top of the system configuration
      Given a system "Core" configured with:
        | Threshold     | 5          |
        | Window Size   | 60 seconds |
        | Cool Off Time | 60 seconds |
      And a light "checkout" in system "Core" configured with:
        | Threshold     | 10         |
        | Cool Off Time | 30 seconds |
      When I visit the lights page for system "Core"
      Then the card for light "checkout" shows a threshold of 10
      And it shows a window size of 60 seconds

  Rule: The panel requires a persistent data store

    # An in-memory store is per-process, so the panel would report on its own process
    # rather than on the application. Failing at boot beats reporting a comforting lie.
    @wip
    Scenario: Configuring a system with a non-persistent data store
      When I configure a system with a non-persistent data store
      Then the configuration fails with error:
        | Type | TypeError |
      And I am told to configure a different data store
