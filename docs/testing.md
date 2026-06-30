---
paths:
  - "spec/**/*.rb"
  - "features/**/*"
---

# Testing conventions

The **TDD protocol** (one failing test at a time. Delete-and-restart if implementation
preceded its test or if multiple failing tests were written at once) lives in
`AGENTS.md` and governs all implementation. This file covers the testing specifics.

## Coverage

- `domain/` and `infrastructure/` must stay at **100% line coverage**. These are the
  layers with no excuse for gaps - domain is pure and infrastructure is exercised
  against real backends.
- Coverage runs through SimpleCov (lcov output, `coverage/lcov.info`). Do **not** use
  `# :nocov:` or delete assertions to hit the number - add the missing test, or delete
  the untested code if it isn't needed.
- AGENTS.md and rules are advisory, not enforced. For a true gate, back the 100% rule
  with SimpleCov `minimum_coverage_by_group` and/or a CI / pre-commit check rather than
  trusting the agent to self-police.

## Feature tests for public interfaces

Every public interface must be covered by a Cucumber **feature test** under
`features/stoplight/`. "Public interface" means the public API surface - `Stoplight()`,
`Stoplight.light`, `Stoplight.configure` - and the observable behaviors they 
expose (tripping, fallback, state control, configuration). New public behavior 
ships with a matching `.feature`, and features must pass against **both**
`STOPLIGHT_DATA_STORE=Memory` and `STOPLIGHT_DATA_STORE=Redis`.

## Test tiers

- `spec/unit/` - fast, isolated, dependency injected. Mirrors `lib/` directory-for-directory and
  is bound by the architecture-boundary cop (see `architecture.md`).
- `spec/integration/` - end-to-end, exercises observable behavior.
- `spec/properties/` - property-based tests using `rantly` (color, DSL, notifications,
  data store invariants).
- `features/stoplight/*.feature` - Cucumber, user-facing behavior. Must pass against
  **both** stores: `STOPLIGHT_DATA_STORE=Memory` and `STOPLIGHT_DATA_STORE=Redis`.

## Doubles vs. real dependencies

Domain collaborator ports are **RBS interfaces** - they have no runtime constant, so
you **cannot** `instance_double` them. The repo ships concrete null implementations in
`spec/support/adapters/` that mirror each port's method surface. Verify doubles against
those.

- Prefer real dependencies to doubles.
- **Collaborator ports** -> double the `Null*` adapter:
  `instance_double(NullStateStore)`, `instance_double(NullMetricsStore)`,
  `instance_double(NullRecoveryLockStore)`, `instance_double(NullRecoveryLockToken)`,
  `instance_double(NullNotifier)`, `instance_double(NullTrafficControl)`,
  `instance_double(NullTrafficRecovery)`, `instance_double(NullClock)`,
  `instance_double(NullDataStore)`, etc..
- **Real domain classes / value objects** -> double them directly, they exist at
  runtime: `instance_double(Stoplight::Domain::Config)`,
  `instance_double(Stoplight::Domain::StateSnapshot)`,
  `instance_double(Stoplight::Domain::MetricsSnapshot)`, etc.
- Never double an **infrastructure** class inside a domain spec - the boundary cop
  forbids it, and the `Null*` adapters exist precisely so you don't have to.
- In **infrastructure** specs, use the **real** dependency (a real `Redis.new(...)`)
  so you exercise actual storage behavior, including Lua scripts.

`NullDataStore` mirrors the **legacy monolithic** port; the focused
`NullStateStore` / `NullMetricsStore` / `NullRecoveryLockStore` adapters mirror the
**new decomposed StorageSet** ports (see `redis-and-storage.md`). Prefer the decomposed
adapters in new domain specs.

## Testing notifiers

`lib/stoplight/rspec.rb` ships the shared example `"a generic notifier"` for any
notifier built on `Stoplight::Notifier::Generic` - use it for built-in and custom
notifiers:

```ruby
require "stoplight/rspec"

RSpec.describe Stoplight::Infrastructure::Notifier::Logger do
  it_behaves_like "a generic notifier"
end
```

## Helpers & hygiene

- `spec/support/` - shared contexts, adapters, data-store and light helpers. Prefer a
  shared example/context over copy-pasting setup.
- Use `timecop` to control time around recovery windows and probes; never `sleep`.
- Redis-touching specs clean state with `database_cleaner-redis`. Don't leak keys
  between examples.
- `spec/dummy/` is a minimal Rails app used only to test the install generator
  (`ammeter`). Keep generator specs there.
- Coverage runs through SimpleCov (lcov output). Don't add `# :nocov:` to dodge a real
  gap - add the missing test.

## Placement

A new spec mirrors the path of the code it covers and stays inside its layer's
directory so the boundary cop applies. New behavior generally wants a unit spec plus,
where it crosses a real store, an integration or property spec.

## TDD: agent failure modes to name, not discover in review

- **Teaching to the test.** Satisfying the letter of the assertion - hardcoding the
  expected value, special-casing the one input - instead of implementing the behavior.
  If you notice yourself hardcoding expected output, stop.
- **Correlated test and code.** When the same context produces both, a misunderstanding
  yields a wrong test and a wrong implementation that agree, and green is a lie. Write
  the test from the desired behavior, not from the implementation you intend. Property
  tests (`spec/properties/`) catch this class of error where example-based tests miss.
- **Not feeling the pain.** If a test needs heavy setup, private-method access, or
  constant stubbing, stop and say so - that is the design pushing back. Injected ports
  (`spec/support/adapters/`) are the fix; if the test is still awkward after using them,
  the design is wrong.

## TDD: rationalizations to reject

- *"I'll test after."* A test written after the code tends to assert what the code
  does, not what it should - and one you never watched fail proves nothing.
- *"Too simple to break."* Simple code breaks too, and the test costs seconds.
- *"I already tested it by hand."* Ad-hoc checking is not a kept, repeatable test;
  the next change has nothing to catch its regression.
- *"Restarting test-first wastes the code I have."* Sunk cost. Untested code is a
  liability; re-deriving it under a test is fast.

The exception is narrow: no behavior to test (config, generated code), or explicitly
told otherwise. Name which exception applies - don't reach for one of the above.
