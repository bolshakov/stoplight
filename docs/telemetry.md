---
paths:
  - "lib/stoplight/telemetry.rb"
  - "lib/stoplight/domain/telemetry/**/*"
  - "lib/stoplight/wiring/notifier_bridge.rb"
  - "sig/stoplight/telemetry.rbs"
  - "sig/stoplight/domain/telemetry/**/*"
---

# Telemetry: Observing Circuit Breaker Behavior

Telemetry is an in-process event bus. Every light publishes what it does - runs, trips, recovery, manual locks,
registration - and any part of your application can subscribe without changing the light's own code. It's the
modern, intended way to observe Stoplight: build a metrics/Statsd integration, log transitions, or feed a paging
system, all through the same bus. (The separate [`stoplight-statsd`] gem is built this way: it subscribes to
`Stoplight.telemetry` and forwards events to Statsd.)

The built-in `notifiers` config option (see the README's Notifiers section) is itself implemented as a telemetry
subscriber under the hood, so anything you can do with a notifier you can also do - with more event types and more
detail per event - by subscribing directly.

[`stoplight-statsd`]: https://github.com/bolshakov/stoplight-statsd

## Quick Start

```ruby
Stoplight.telemetry.subscribe(Stoplight::Telemetry::TrafficBreached) do |envelope|
  logger.warn("#{envelope.light_name} tripped: #{envelope.payload.failure&.exception&.message}")
end

Stoplight.telemetry.subscribe(Stoplight::Telemetry::RecoverySucceeded) do |envelope|
  logger.info("#{envelope.light_name} recovered")
end
```

`Stoplight.telemetry` gives you the **default system's** telemetry bus: you can subscribe and unsubscribe, but only
the light itself publishes to it. Named systems have their own bus - see [Per-System Telemetry](#per-system-telemetry)
below.

## The Envelope

Every event arrives wrapped in an `Envelope`:

```ruby
envelope.system_name  # String
envelope.light_name   # String
envelope.occurred_at  # Time
envelope.payload      # the event itself, e.g. a TrafficBreached instance
```

`occurred_at` and the identifying names are attached by the bus at publish time, so every event carries them
regardless of which payload class it is.

## Subscribing

```ruby
Stoplight.telemetry.subscribe(EventClass) { |envelope| ... }
```

`subscribe` accepts three kinds of filter:

- **No filter** (`subscribe { |envelope| ... }`) - every event, including event types added in a future version.
  Narrow on `envelope.payload.class` or `case envelope.payload` yourself.
- **A specific event class** (`subscribe(Stoplight::Telemetry::RunCompleted) { ... }`) - only that event.
- **`Stoplight::Telemetry::StateTransitioned`** - every event that changes a light's color, as a
  fixed group: `TrafficBreached`, `RecoveryStarted`, `RecoverySucceeded`, `RecoveryFailed`, `LockChanged`. Subscribe
  to this to reconstruct a light's full color timeline without listing each transition event individually.

`#subscribe` returns a `Subscription` token; pass it to `#unsubscribe` to stop receiving events. Unsubscribing an
already-removed or unknown token is a no-op.

## Events

| Event | Emitted when | Fields |
|---|---|---|
| `RunCompleted` | Every `Light#run`. | `outcome`, `color`, `duration_ms`, `failure`, `fallback_used`, `retry_after` |
| `TrafficBreached` | Trip: green -> red. | `from_color`, `to_color`, `policy`, `failure`, `metrics` |
| `RecoveryStarted` | Cool-off elapses, red -> yellow. | `from_color`, `to_color`, `breached_at` |
| `RecoverySucceeded` | Recovery succeeds, yellow -> green. | `from_color`, `to_color`, `policy`, `metrics` |
| `RecoveryFailed` | Recovery fails, yellow -> red. | `from_color`, `to_color`, `policy`, `failure`, `metrics` |
| `LockChanged` | Manual lock/unlock. | `from_color`, `to_color`, `from_state`, `to_state` |
| `RecoveryProbeCompleted` | Every probe run while yellow. | `outcome`, `duration_ms`, `failure`, `progress` |
| `LightRegistered` | Once per process per (system, light). | `settings` |

`TrafficBreached`, `RecoveryStarted`, `RecoverySucceeded`, `RecoveryFailed`, and `LockChanged` all include the
`StateTransitioned` marker module (see [Subscribing](#subscribing)). `LockChanged` fires even when the resulting
color is unchanged, so the lock timeline is complete. `from_color`/`to_color` are the string colors (`"green"`,
`"yellow"`, `"red"`); `from_state`/`to_state` on `LockChanged` are lock states (`"unlocked"`, `"locked_green"`,
`"locked_red"`).

`failure`, where present, is a `Failure` wrapping the live `exception` and a `tracked` flag (`false` when the
exception matched `skipped_errors` - the run still counted as a success). `metrics`/`progress` are a `Metrics`
snapshot (`successes`, `errors`, `consecutive_errors`, `consecutive_successes`) at the decision point; `settings` on
`LightRegistered` is the serializable subset of a light's configuration (thresholds, window size, policies).

## Error Isolation

A subscriber that raises never affects the light or the caller's `run`. The bus catches the error, routes it to the
configured `error_notifier` (`Stoplight.configure { |c| c.error_notifier = ... }`), and moves on to the next
subscriber. A circuit breaker is a reliability tool - a broken metrics integration must not become an outage.

## Cost When Nobody's Listening

Emitting an event allocates nothing if no subscriber is interested in that event class - subscribing only to
`StateTransitioned` events keeps every `RunCompleted` emission free. This makes it safe to instrument selectively
without worrying about the cost of the events you don't subscribe to.

## Per-System Telemetry

Each system - the default one and every one created with `Stoplight.register_system` - has its own, independent
telemetry bus:

```ruby
Payments = Stoplight.register_system("Payments")
Payments.register("stripe")

Payments.telemetry.subscribe(Stoplight::Telemetry::TrafficBreached) do |envelope|
  alert("Payments system: #{envelope.light_name} tripped")
end
```

Subscribing on `Stoplight.telemetry` only sees events from the default system's lights. See the [Systems guide]
for when and why to use named systems.

[Systems guide]: systems.md
