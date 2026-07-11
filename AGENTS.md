# Stoplight

Ruby gem implementing the circuit breaker pattern. This is library code, not an application. 
Public API lives in `lib/stoplight.rb`.

<!-- maintainer note: keep this file short (<~80 lines). Deep, path-specific detail
     belongs in docs/*.md and .claude/rules/*.md so it only loads when those files 
are touched. -->

## Commands

```shell
bundle install                                                # install deps
bundle exec standardrb --fix                                  # lint with autofix
bundle exec steep check                                       # RBS type check
bundle exec rspec                                             # all specs
bundle exec rspec spec/unit/stoplight/domain/light_spec.rb:42 # run one file/example
STOPLIGHT_DATA_STORE=Memory bundle exec cucumber              # features with Memory store
STOPLIGHT_DATA_STORE=Redis bundle exec cucumber               # features with Redis store
```

## Architecture

Clean Architecture, four layers, dependencies point **inward only**. A custom cop
(`Stoplight/ArchitectureBoundaries`, severity **error**) enforces this - a violation
fails lint:

| Layer (`lib/stoplight/…`) | May depend on                  |
|---------------------------|--------------------------------|
| `domain/`                 | nothing                        |
| `infrastructure/`         | domain                         |
| `wiring/`                 | domain, infrastructure         |
| `admin/`                  | domain, infrastructure, wiring |

- **Domain is pure**: no I/O, no Redis, no gems. It defines interfaces as **RBS type
  signatures only** (`sig/_private/stoplight/domain/ports/`), never Ruby base classes.
- **Infrastructure implements** those interfaces by **duck typing** (no inheritance).
- Domain must never reference the composition root (`Stoplight.light` /
  `Stoplight.register` / `.configure` / `.light` / `Stoplight()`) or the root aliases
  `Stoplight::DataStore` / `Stoplight::Notifier`. Use `Domain::Light` and
  domain interfaces directly.
- The same boundary rule applies to specs under `spec/unit/<layer>/`.

Full detail: `docs/architecture.md`.

## Conventions

- `# frozen_string_literal: true` at the top of every Ruby file.
- Let zeitwerk autoload - no manual `require` inside `lib/`. File path = constant path.
- Internal-but-public plumbing uses the `__stoplight__` prefix.
- Public surface is only: `Stoplight()`, `Stoplight.register`, `Stoplight.light`,
  `Stoplight.configure`, `Light#run`
- Public API methods require a doc comment with at least one usage example -
  see `lib/stoplight.rb` for the pattern. Document behavior, not types - types
  belong in RBS (`docs/types_and_rbs.md`).
- Domain collaborator ports are RBS interfaces with **no runtime constant** - test
  doubles use the `Null*` classes in `spec/support/adapters/`, e.g.
  `instance_double(NullStateStore)`. See `docs/testing.md`.
- Any change in `lib/` needs matching RBS in `sig/` (see `docs/types_and_rbs.md`).

## Where things live

- `domain/` - light state machine, colors (green/yellow/red), failure model, run
  strategies, `traffic_control` (`consecutive_errors`, `error_rate` -> trip to red),
  `traffic_recovery` (`consecutive_successes`), recovery probes + recovery locks.
- `infrastructure/` - memory + redis stores, notifiers, `fail_safe` wrappers. Redis
  writes go through co-located Lua scripts for atomicity. Storage is a decomposed
  `Storage`/`StorageSet` model - target the focused stores for new work.
- `wiring/` - dependency injection / composition root, config DSLs, defaults.
- `admin/` - optional Sinatra dashboard (excluded from Steep type checking).
- `sig/` - RBS; `sig/_private/` holds internal interfaces. `bench/` - benchmarks.
  `spec/dummy/` - a Rails app used to test the install generator.
