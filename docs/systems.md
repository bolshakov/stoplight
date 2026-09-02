---
paths:
  - "sig/stoplight/ports/system.rbs"
  - "lib/stoplight/wiring/system.rb"
---


# Systems: Namespace Isolation & Configuration

By default, Stoplight uses a single global system. All lights you create with `Stoplight.register()` and
`Stoplight.light()` share that system's configuration, data store, and notifiers.

For more complex applications, you can create **named systems** — completely isolated instances with their own
configuration, data store, and registry.

## When to Use Multiple Systems

### Multi-tenancy

Each tenant gets its own system with separate Redis databases or separate data stores entirely:

```ruby
tenant_a = Stoplight.register_system("Tenant A", data_store: tenant_a_redis)
tenant_b = Stoplight.register_system("Tenant B", data_store: tenant_b_redis)

# Same circuit name, completely isolated state
tenant_a.register("api")
tenant_b.register("api")

tenant_a.light("api").run { fetch_for_tenant_a }
tenant_b.light("api").run { fetch_for_tenant_b }
```

### Service Boundaries

Separate systems for payment, analytics, and reporting services with independent SLOs:

```ruby
Payments = Stoplight.register_system("Payments", threshold: 3, cool_off_time: 30)
Analytics = Stoplight.register_system("Analytics", threshold: 5, cool_off_time: 60)

Payments.register("stripe")
Analytics.register("mixpanel")
```

### Independent Data Stores

Different services require different storage backends:

```ruby
# Payments uses Redis for persistence
Payments = Stoplight.register_system(
  "Payments",
  data_store: Stoplight::DataStore::Redis.new(payments_redis)
)

# Analytics uses in-memory store (loses state on restart, by design)
Analytics = Stoplight.register_system(
  "Analytics",
  data_store: Stoplight::DataStore::Memory.new
)
```

## System vs. Default System

The **default system** is created automatically when you first call `Stoplight.configure` or use `Stoplight.register()`.
It uses global configuration:

```ruby
Stoplight.configure do |config|
  config.data_store = redis
  config.threshold = 3
  config.cool_off_time = 60
end

# Uses the default system's config
Stoplight.register("api")
Stoplight.light("api").run { ... }

# or more conveniently, an alias to .register("api").run {}
Stoplight("api").run { }
```

**Named systems** are explicitly created and independent:

```ruby
# Does NOT use Stoplight.configure settings
custom = Stoplight.register_system("Custom", threshold: 5, cool_off_time: 120)
custom.register("api") # Different from default system's "api"
```

## Boot-Time Registration

Register all lights when your application starts, not inline at call sites:

```ruby
# config/initializers/stoplight.rb
Stoplight.configure do |config|
  config.data_store = Redis.new
end

Payments = Stoplight.register_system("Payments", threshold: 5)
Payments.register("stripe", cool_off_time: 30)
Payments.register("paypal", cool_off_time: 45)

Analytics = Stoplight.register_system("Analytics")
Analytics.register("amplitude")
Analytics.register("mixpanel")
```

Then use `.light()` lookups throughout your app:

```ruby
# app/services/payment_service.rb
def process_payment
  Payments.light("stripe").run { stripe_api.charge(amount) }
end
```

**Benefits:**

- **Single source of truth**: All light names and settings in one place
- **Caching**: Lights are cached after first registration; `.light()` lookups are fast
- **Configuration consistency**: Registering the same light twice with different settings raises an error, preventing
  silent configuration drift
- **Thread-safe**: Multiple threads can safely call `.light()` concurrently

## Configuration Inheritance & Overrides

System-level defaults are inherited by all lights in that system. Individual lights can override:

```ruby
system = Stoplight.register_system(
  "Services",
  threshold: 3, # System default
  cool_off_time: 60,
  window_size: 300
)

# Inherits threshold: 3, cool_off_time: 60
system.register("api")

# Overrides threshold to 5, keeps cool_off_time: 60
system.register("payment", threshold: 5)

# Overrides both
system.register("upload", threshold: 10, cool_off_time: 120)
```

If you do NOT register a light beforehand, you can still create one inline in a default system:

```ruby
light = Stoplight("adhoc", threshold: 7)
light.run { ... }
```

## Configuration Conflicts

If you try to register the same light twice with different settings, Stoplight raises an error:

```ruby
system.register("api", threshold: 3)
system.register("api", threshold: 5) # raises ConfigurationError
```

This prevents the subtle bug where two call sites silently disagree on a light's configuration. The error shows both
registration locations:

```
Light `api` already registered with different configuration.
Original registration: config/initializers/stoplight.rb:42:in `<top (required)>'
Current attempt: app/services/payment_service.rb:15:in `initialize'

Lights must have consistent configuration across all call sites.
```

## Isolation Guarantees

- **State isolation**: Each system has its own state store. Tripping one system's light does not affect another.
- **Registry isolation**: Lights are namespaced by system. Two systems can both have a light named `"api"` with no
  conflict even when using the same underlying data store.
- **Configuration isolation**: Each system has independent defaults; named systems ignore `Stoplight.configure()`.
- **Notifiers isolation**: Each system can have different notifiers (or none).

```ruby
sys_a = Stoplight.register_system("A", data_store: store_a, notifiers: [notifier_a])
sys_b = Stoplight.register_system("B", data_store: store_b, notifiers: [notifier_b])

sys_a.register("api", threshold: 3)
sys_b.register("api", threshold: 10)

# One trips red; the other is unaffected
sys_a.light("api").run { fail_three_times } # trips to red
sys_b.light("api").run { fail_once } # still green
```

## Accessing Telemetry by System

Each system has its own telemetry bus:

```ruby
Payments = Stoplight.register_system("Payments")
Payments.register("stripe")

# Subscribe to events from the Payments system only
Payments.telemetry.subscribe(Stoplight::Telemetry::LightTripped) do |envelope|
  alert("Payments system: #{envelope.event.light_name} tripped")
end
```

The default system's telemetry is also accessible globally:

```ruby
Stoplight.telemetry.subscribe(Stoplight::Telemetry::LightTripped) do |envelope|
  log("Light #{envelope.event.light_name} tripped")
end
```
