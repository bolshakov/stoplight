---
paths:
  - "lib/stoplight/infrastructure/redis/**/*"
  - "lib/stoplight/infrastructure/memory/**/*"
  - "lib/stoplight/infrastructure/storage/**/*"
  - "lib/stoplight/infrastructure/fail_safe/**/*"
---

# Data storages

These are infrastructure implementations of domain storage ports. They may depend on
the domain, never on wiring or admin. Currently supported backends: **Memory** and
**Redis**.

## Storage model

Storage is a decomposed `StorageSet`: focused stores for state, metrics (windowed vs
unbounded), recovery-lock, and recovery-metrics, assembled by `Wiring::StorageSetBuilder`.
`StorageSetBuilder` is the single place the windowed/unbounded metrics decision is made.
The `Storage` classes live under `infrastructure/{backend}/storage/`.

## Atomicity

State transitions and metric updates that must be atomic are implemented per backend
using whatever primitive that backend offers for it. The Redis backend uses **Lua
scripts**, co-located with the Ruby that loads them (`*.lua` next to the `.rb`, e.g.
`window_metrics/record_failure.lua`, `state/transition_to_red.lua`). When you add or
change a multistep mutation against a backend with such a primitive, use it rather than
several round trips - a half-applied transition corrupts the breaker's state.

## Fail-safe

The `fail_safe/` wrappers exist so the circuit breaker's **own** storage or notifier
failure never propagates to the caller. A breaker is a reliability tool - if a backend is
down, Stoplight must degrade gracefully, not raise. Preserve this: new store/notifier
methods that can perform I/O should be reachable through the fail-safe wrapper.

## Backend parity

All backends must keep the **same observable semantics** so unit tests and the cucumber
run are meaningful regardless of which backend they run against. If you change behavior
in one backend, change it in all of them (and add/adjust the property or integration
spec that pins the invariant).

## Backward compatibility

Don't change a backend's key layout without a deliberate deprecation - existing users
have live backend state in the current format and such change considered breaking and 
requires major version update.
