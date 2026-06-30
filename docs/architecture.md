---
paths:
  - "lib/stoplight/**/*.rb"
  - "spec/unit/stoplight/**/*_spec.rb"
  - "sig/**/*.rbs"
---

# Architecture & layer boundaries

Stoplight follows Clean Architecture. Dependencies flow inward. The domain knows
nothing about the outside world. The `Stoplight/ArchitectureBoundaries` cop
(severity `error`) enforces the matrix below across both `lib/` and `spec/unit/`.

| Layer             | Allowed dependencies           | Role                                   |
| ----------------- | ------------------------------ | -------------------------------------- |
| `domain/`         | (none)                         | Pure business logic                    |
| `infrastructure/` | domain                         | I/O: storage, notifiers, fail-safe     |
| `wiring/`         | domain, infrastructure         | Composition root, DI, config DSLs      |
| `admin/`          | domain, infrastructure, wiring | Sinatra dashboard                      |

## Dependency inversion (how domain stays pure)

The domain depends on **interfaces it defines as RBS type signatures**, not on Ruby
classes. Example interface: `Stoplight::Domain::_DataStore` in
`sig/_private/stoplight/domain/ports/`. There is intentionally **no Ruby base class**
in `lib/stoplight/domain/` for these ports.

Infrastructure satisfies a port by **duck typing** - it implements the methods, it does
not inherit anything:

```ruby
module Stoplight::Infrastructure::Memory
  class DataStore            # no inheritance; conforms to Domain::_DataStore
    def get_metrics(config) = ...
    def get_state_snapshot(config) = ...
    def record_failure(config, exception) = ...
  end
end
```

## Hard rules for domain code

- No `require`/reference to Redis, IO, Sinatra, or any infrastructure constant.
- Never call the composition root: `Stoplight.light`, `Stoplight.configure`, 
  or `Stoplight(...)`.
- Never reference the root aliases `Stoplight::DataStore` / `Stoplight::Notifier`.
  Reference `Stoplight::Domain::…` directly instead.
- These same prohibitions apply to `spec/unit/stoplight/domain/**` - build collaborator
  doubles from the `Null*` adapters in `spec/support/adapters/` (the ports are RBS
  interfaces with no runtime constant, so you can't `instance_double` them), never from
  infrastructure classes. See `testing.md`.

## Adding a capability (where code goes)

- New storage work -> target the **decomposed StorageSet** (focused state, metrics,
  recovery-lock, and recovery-metrics stores), **not** the legacy monolithic
  `DataStore`, which is being phased out. Implement the focused store(s) under
  `infrastructure/{backend}/storage/` and assemble them via `Wiring::StorageSetBuilder`.
  Mirror the existing memory/redis pairing and keep Redis writes atomic (see
  `redis-and-storage.md`).
- New notifier -> implement the notifier interface under `infrastructure/notifier/`,
  register it in `wiring/notifier_factory.rb`. Consider implementing as gem rather 
  adding here.
- New trip/recovery policy -> it's domain logic: add it under
  `domain/traffic_control/` or `domain/traffic_recovery/` and expose it through the
  wiring DSL - do **not** reach into infrastructure from there.

When the cop reports `X cannot depend on Y`, the fix is almost always to move the logic
to the correct layer or to depend on a domain port instead of a concrete class - not to
disable the cop.

## Common violations

### Domain directly referencing infrastructure

```ruby
# BAD - domain/light.rb
Stoplight::Infrastructure::Notifier::IO.new.notify(...)  # hard dependency on concrete class

# GOOD - call through the injected port (duck-typed)
@notifiers.each { |n| n.notify(config, from_color, to_color) }
# Interface: sig/_private/stoplight/domain/ports/state_transition_notifier.rbs
```

### Domain requiring an external gem

```ruby
# BAD - domain/light.rb
require 'redis'
Redis.new.set(...)  # I/O in domain

# GOOD - call through the injected port
@data_store.record_success(config)
# Infrastructure owns Redis; domain never sees it
# Interface: sig/_private/stoplight/domain/ports/
```

### Abstract base class instead of RBS interface

```ruby
# BAD (old pattern, fully removed)
# lib/stoplight/domain/data_store.rb
module Stoplight::Domain
  class DataStore
    def get_metrics(config) = raise NotImplementedError  # runtime coupling
  end
end

# GOOD (current pattern)
# sig/_private/stoplight/domain/ports/data_store.rbs
module Stoplight::Domain
  interface _DataStore
    def get_metrics: (Config) -> MetricsSnapshot
  end
end
# No .rb file. Steep validates at development time; zero runtime coupling.
```
