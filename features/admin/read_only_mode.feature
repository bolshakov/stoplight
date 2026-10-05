Feature: Admin Read-Only Mode
  As someone deploying the panel more widely than the people allowed to change things
  I want an observation-only mode that refuses writes at the server
  So that hiding a button is not the only thing standing between a viewer and a locked circuit

  Background:
    Given an admin panel in read-only mode
    And a red light "checkout" exists

  Rule: Reading works exactly as normal

    @wip
    Scenario: Every light stays visible
      When I visit the lights page
      Then I see light "checkout"
      And the card for light "checkout" is titled "Last Error"

    @wip
    Scenario: The JSON endpoints still serve
      When I request the lights JSON
      Then the request succeeds
      And the payload includes light "checkout"

  Rule: Controls lose their action, not their place

    # The layout should not shift between modes - a viewer sees the same page, inert.
    @wip
    Scenario: Controls render as disabled
      When I open the actions for light "checkout"
      Then the "Lock Green" control is disabled
      And it is marked as disabled to assistive technology
      And it is titled "Disabled in read-only mode"

  Rule: Refusal happens at the server, on the request method

    # Gating on the verb rather than on a path list means a write route added later is
    # refused without anyone having to remember this filter exists.
    @wip
    Scenario Outline: Write requests are refused even when sent directly
      When I send a <verb> request to <path>
      Then the request fails with status 403
      And I am told the panel is running in read-only mode
      And light "checkout" is unchanged

      Examples:
        | verb   | path                  |
        | PATCH  | the lock endpoint     |
        | PATCH  | the unlock endpoint   |
        | PATCH  | the lock-all endpoint |
        | DELETE | the remove endpoint   |

    @wip
    Scenario Outline: Read requests pass through
      When I send a <verb> request to the lights page
      Then the request succeeds

      Examples:
        | verb |
        | GET  |
        | HEAD |

  Rule: Read-only is not access control

    # There are no users and no authentication here. Anyone who reaches the panel reads
    # every light name and every error message, including anything an exception leaked.
    @wip
    Scenario: A viewer can still read everything
      Given a red light "billing" exists
      And light "billing" last failed with "Customer 4242 not found"
      When I visit the lights page
      Then the card for light "billing" shows "Customer 4242 not found"

  Rule: The standalone image reads the same setting from the environment

    @wip
    Scenario Outline: The environment variable is exact-match
      Given STOPLIGHT_ADMIN_READ_ONLY is set to "<value>"
      When the standalone panel boots
      Then read-only mode is <state>

      Examples:
        | value | state |
        | true  | on    |
        | TRUE  | off   |
        | 1     | off   |
        | yes   | off   |
        |       | off   |
