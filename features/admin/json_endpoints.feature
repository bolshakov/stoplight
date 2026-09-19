Feature: Admin JSON Endpoints
  As an external monitor or a script
  I want the same light data the panel renders, as JSON
  So that I can poll circuit health without scraping HTML

  Background:
    Given an admin panel backed by a persistent data store

  Rule: The payload carries the lights and the color counts

    @wip
    Scenario: Requesting a system's lights as JSON
      Given a system "Core" is configured
      And the following lights in system "Core" exist:
        | Name            | Color  |
        | Payment Gateway | red    |
        | Social Media    | yellow |
        | Cache Layer     | green  |
      When I request the lights JSON for system "Core"
      Then the payload has a "stats" object with:
        | count_red      | 1  |
        | count_yellow   | 1  |
        | count_green    | 1  |
        | percent_red    | 34 |
        | percent_yellow | 34 |
        | percent_green  | 34 |
      And the payload has 3 lights
      And the payload lists the lights in this order:
        | Payment Gateway |
        | Social Media    |
        | Cache Layer     |

  Rule: Each light carries its identity, its color and its lock state

    @wip
    Scenario: The shape of a light
      Given a red light "Payment Gateway" exists
      And light "Payment Gateway" last failed with "execution expired"
      When I request the lights JSON
      Then the payload includes light "Payment Gateway" with:
        | name   | Payment Gateway |
        | color  | red             |
        | locked | false           |
      And it has an identifier
      And its failures include the last error

    @wip
    Scenario: A light with no recorded error has an empty failures list
      Given a green light "Cache Layer" exists
      When I request the lights JSON
      Then the payload includes light "Cache Layer"
      And its failures are empty

    @wip
    Scenario: A locked light reports so
      Given a light "checkout" exists
      And light "checkout" is locked to green
      When I request the lights JSON
      Then the payload includes light "checkout" with:
        | locked | true |

    # The identifier survives restarts and redeploys, so a monitor can key on it.
    @wip
    Scenario: The identifier is stable across requests
      Given a light "checkout" exists
      When I request the lights JSON twice
      Then the identifier of light "checkout" is the same both times

  Rule: An empty system returns zeroes rather than nothing

    @wip
    Scenario: No lights registered
      Given no lights exist
      When I request the lights JSON
      Then the payload has no lights
      And the payload has a "stats" object with:
        | count_red      | 0 |
        | count_yellow   | 0 |
        | count_green    | 0 |
        | percent_red    | 0 |
        | percent_yellow | 0 |
        | percent_green  | 0 |

  Rule: The unscoped endpoint is kept for monitors that already poll it

    @wip
    Scenario: Unscoped stats report the first configured system
      Given systems "Core" and "Analytics" are configured in that order
      And a green light "Cache Layer" in system "Core" exists
      And a red light "Event Ingest" in system "Analytics" exists
      When I request the unscoped stats JSON
      Then the payload has a "stats" object with:
        | count_red | 0 |
      And the payload includes light "Cache Layer"
      And the payload does not include light "Event Ingest"
