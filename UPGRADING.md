## Stoplight 6.0

Stoplight 6.0 is built around a single idea: a light is a named thing your application declares once, not an object
you rebuild at every call site. Most of the changes below follow from that. The first two need some thought, the rest
are mechanical.

Here's what you'll want to tackle during your upgrade, roughly ordered from the most involved to the most trivial:

- [ ] Make every `Stoplight("name", ...)` call site for the same name pass identical settings
- [ ] Move `data_store`, `notifiers`, and `error_notifier` from individual lights to `Stoplight.configure`
- [ ] Replace the `with_*` builder methods with settings passed at creation time
- [ ] Replace proc and anonymous-class error matchers with named classes or modules
- [ ] Account for Stoplight state reset after deployment
- [ ] Re-check `error_rate` lights - `min_requests` is gone and the fixed minimum sample is now 100 requests
- [ ] Drop `warn_on_clock_skew` from your Redis data store setup
- [ ] Test thoroughly in a staging environment

### Lights Are Registered and Reused

In 5.x, each `Stoplight("Payment Service", threshold: 5)` call built a brand-new light. Nothing tied the call sites
together, so two places could configure the same name differently and both would run - which settings a process ended
up with depended on which file it executed.

In 6.0, `Stoplight()` registers the light on first call and returns that same cached instance afterwards. If a later
call passes settings that differ from the registration, Stoplight raises `Stoplight::Error::ConfigurationError`. The
message names where the light was first registered, and the error's backtrace points at the conflicting call:

```
Light `Payment Service` already registered with different configuration.

Originally registered at:
  app/services/payment_service.rb:14:in 'charge'

Lights must have consistent configuration across all call sites.
```

Your existing code keeps working as long as each name is configured consistently, so for many applications this
upgrade is a no-op until a stray call site raises. The more durable fix is to register lights once at boot and look
them up by name:

```ruby
# config/initializers/stoplight.rb
Stoplight.register("Payment Service", threshold: 5, cool_off_time: 60)
```

```ruby
# anywhere else in your app
Stoplight.light("Payment Service").run { payment_gateway.charge(order) }
```

`Stoplight()` still works everywhere it used to - it just expects the same settings each time. `Stoplight.light` is
the alternative: it takes a name and nothing else, so there's no settings list to keep in sync, and it raises
`Stoplight::Error::UnregisteredLightError` if that name was never registered.

Lights built from dynamic names (`Stoplight("api-#{endpoint}")`) still work - caching is per name, so each distinct
name registers once.

### Infrastructure Configuration Moved Out of Individual Lights

`Stoplight()` and `Stoplight.light()` no longer accept `data_store`, `notifiers`, or `error_notifier`. Passing them
now raises `ArgumentError: unknown keyword`.

These options aren't per-circuit behavior - they describe where your application keeps state and how it reports
problems. When each light could carry its own, the same light name could end up backed by different stores in
different processes, so instances never saw each other's failures. It also left no single place listing which lights
exist and where their state lives, which the Admin dashboard's registry needs.

```ruby
# Old way that won't work anymore
light = Stoplight("Payment Service", data_store: Stoplight::DataStore::Redis.new(redis))
```

Configure infrastructure once, at boot:

```ruby
# New way
Stoplight.configure do |config|
  config.data_store = Stoplight::DataStore::Redis.new(redis)
  config.notifiers = [Stoplight::Notifier::Logger.new(Rails.logger)]
  config.error_notifier = ->(error) { Bugsnag.notify(error) }
end
```

If you genuinely need more than one data store - separate Redis instances per tenant, for example - use named
systems, which own their own infrastructure. See [Systems: Namespace Isolation & Configuration][systems] for setup.

### The Light Builder API Is Gone

`Light#with` and the whole `with_*` family are removed: `with_data_store`, `with_cool_off_time`, `with_threshold`,
`with_window_size`, `with_notifiers`, `with_error_notifier`, `with_tracked_errors`, and `with_skipped_errors`. They
were marked deprecated in 5.0 and have printed a warning naming this release since 5.7, so most codebases should
already be clean.

Cloning a light produced a second light sharing the first one's name but not its settings - exactly the configuration
drift the registration model now rejects.

```ruby
# Old way
light = Stoplight("Payment Service").with_threshold(10).with_cool_off_time(30)

# New way
light = Stoplight("Payment Service", threshold: 10, cool_off_time: 30)
```

If you were cloning in order to vary error handling per call, you don't need a second light for that anymore -
`#run` takes per-call overrides:

```ruby
light.run(skipped_errors: [ActiveRecord::RecordNotFound]) { find_customer }
```

### Error Matchers Must Be Named Classes or Modules

`tracked_errors` and `skipped_errors` accept named `Class` or `Module` constants only - `StandardError`, your own
error classes, or a custom class or module overriding `===`. Procs, anonymous classes (`Class.new(StandardError)`),
and instances raise `ArgumentError`. In 5.x anything responding to `===` was accepted.

Both the registry and the consistency check need a matcher's *name*. The registry writes each light's configuration
to Redis so the Admin dashboard can list lights it never loaded, and a matcher is stored there as its class name - a
proc has no name to write. Comparing call sites has the same problem from the other direction: two files that each
build their own `->(error) { ... }` produce two different objects, so identical-looking configuration would be
reported as a conflict. A constant is the same matcher everywhere it's mentioned.

```ruby
# Old way that won't work anymore
light = Stoplight("Payment Service", skipped_errors: [->(error) { error.is_a?(Timeout::Error) }])

# New way
light = Stoplight("Payment Service", skipped_errors: [Timeout::Error])
```

For matching that genuinely needs logic, give it a name and let it override `===`:

```ruby
module TransientHTTPError
  def self.===(error) = error.is_a?(Net::HTTPError) && error.response.code.start_with?("5")
end

light = Stoplight("Payment Service", tracked_errors: [TransientHTTPError])
```

The restriction applies to registration only. The same two lists can be passed to `#run` as a per-call override, and
those are never registered, serialized, or compared against another call site - so anything responding to `===` still
works there, procs included:

```ruby
light.run(skipped_errors: ->(error) { error.message.include?("rate limit") }) { charge_card }
```

### Redis Data Gets a Fresh Start Again

Like 5.0 before it, 6.0 moves to a new Redis key schema. Keys are now namespaced `stoplight:v6:...` instead of
`stoplight:v5:...`, and the storage behind them was decomposed into focused stores for state, metrics, and recovery
locks.

The reason is the same one that motivated the split: a single monolithic key structure made every read pull data no
caller needed, and it left no room for the per-light configuration the registry and dashboard now persist. Migrating
the old format would have meant a rewrite of live data for a value that decays within minutes anyway.

Nothing to change in your code. After deploying, every circuit breaker starts green with no history. For most
applications that's a non-event, since circuit breakers are meant to react to current conditions - but if you're
deploying while a dependency is already failing, expect the first failures after the deploy to be passed through
before the light trips again.

Your old `stoplight:v5:*` keys are ignored from the moment you deploy, and they carry TTLs, so they expire on their
own. There's no cleanup to do.

### Error Rate No Longer Takes `min_requests`

The `error_rate` traffic control strategy dropped its `min_requests` option. The minimum sample size is now fixed at
100 requests internally, up from a default of 10.

This changes behavior even if you never passed the option: an `error_rate` light now needs 100 requests in its window
before it can trip at all.

An error rate is only a useful signal when it's measured over enough requests. Across 10 requests - the old default -
a single failure moves the rate by 10 percentage points, so the light reacted to normal variation as readily as to a
real problem. At 100 requests each individual request moves the measurement by one point, which is stable enough to
act on. Since the value that makes the strategy trustworthy is the one nobody should tune down, it stopped being a
knob.

The practical consequence is that `error_rate` is a strategy for lights that see real traffic. If a light won't see
100 requests within its `window_size`, use `:consecutive_errors` instead.

```ruby
# Old way that won't work anymore
light = Stoplight("Payment Service", traffic_control: {error_rate: {min_requests: 10}}, threshold: 0.5)

# New way
light = Stoplight("Payment Service", traffic_control: :error_rate, threshold: 0.5, window_size: 300)
```

The hash form of `traffic_control` is gone entirely, so passing it raises `Stoplight::Error::ConfigurationError`.
`Stoplight::Domain::TrafficControl::ErrorRate.new` takes no arguments.

### Clock Skew Detection Is Gone

`Stoplight::DataStore::Redis.new` no longer accepts `warn_on_clock_skew:`. Passing it raises `ArgumentError`.

```ruby
# Old way that won't work anymore
Stoplight::DataStore::Redis.new(redis, warn_on_clock_skew: false)

# New way
Stoplight::DataStore::Redis.new(redis)
```

All time-dependent decisions are now made from Redis's own clock, so every instance reads the same time no matter
what its host believes. With the coordination problem solved at the source, there is no skew left to warn about.

### Getting Help

If you run into anything this guide doesn't cover, post to our [Discussions forum]. The configuration errors in 6.0
try hard to tell you exactly which two call sites disagree and what to do about it, so start by reading the message
in full - it usually names the file and line you need.

## Stoplight 5.0 

Stoplight 5.0 introduces several breaking changes, so you'll need to set aside some time to update your code. The good 
news is that most of the changes are pretty straightforward, and once you're done, you'll have a much cleaner and 
more powerful setup.

Here's what you'll want to tackle during your upgrade. Don't worry if this looks like a lot - most of these are simple 
find-and-replace operations:

- [ ] Update global configuration to use the new block syntax
- [ ] Replace any remaining `Stoplight() {}` calls with `Stoplight().run {}`
- [ ] Convert error handlers to tracked/skipped error lists
- [ ] Move fallbacks from configuration to `#run` method calls
- [ ] Account for Stoplight state reset after deployment
- [ ] Test thoroughly in a staging environment

### Global Configuration Redesign

The biggest change you'll see is how global configuration works. We've moved away from individual setter methods to a 
unified configuration block. The old individual setters were causing race conditions in production - imagine 
one part of your app setting the data store while another part was setting notifiers, and depending on timing, you could 
end up with inconsistent configuration states. The new block-based approach ensures all your settings are applied 
atomically, which eliminates these edge cases completely.

If you have code that looks like this:

```ruby
# Old way that won't work anymore
Stoplight.default_data_store = Stoplight::DataStore::Redis.new(redis)
Stoplight.default_notifiers += [Stoplight::Notifier::Logger.new(Rails.logger)]
Stoplight.default_error_notifier = ->(error) { Bugsnag.notify(error) }
```

You'll need to convert it to the new block syntax:

```ruby
# New way that's much more reliable
Stoplight.configure do |config|
  config.data_store = Stoplight::DataStore::Redis.new(redis)
  config.notifiers += [Stoplight::Notifier::Logger.new(Rails.logger)]
  config.error_notifier = ->(error) { Bugsnag.notify(error) }
end
```

The new approach ensures all your configuration is applied atomically, which prevents some weird edge cases where 
partial configuration changes could cause unexpected behavior.

### Cleaning Up Old Deprecated Code

Remember `Stoplight() {}` interface that got deprecated way back in 4.0? Well, it's finally gone completely. If you 
still have any of these in your codebase, you'll need to convert them to use the run method:

```ruby
# This won't work anymore
Stoplight('API Call') { make_api_request }.run

# Change it to this
Stoplight('API Call').run { make_api_request }
```

Most codebases shouldn't have these anymore since they've been deprecated for a while, but it's worth doing a quick 
grep to make sure.

### Error Handling Gets Much Simpler

This is probably the change you'll appreciate most once you're used to it. The old `with_error_handler` callback system 
was confusing and led to a lot of boilerplate code, but more importantly, it was a source of bugs. We kept 
seeing cases where developers would forget to call the handler properly, or accidentally raise errors when they meant 
to track them, or create configuration that leaked between different circuit breakers. The new approach is much more 
straightforward and eliminates these problems entirely - you just tell Stoplight which errors to track and which to ignore.

If you have complex error handler logic like this:

```ruby
# Old complicated way
light = Stoplight('api-call')
  .with_error_handler do |error, handle|
    if error.is_a?(ActiveRecord::RecordNotFound) || error.is_a?(ActiveRecord::RecordInvalid)
      raise error  # Don't track this error
    else
      handle.call(error)  # Track this error
    end
  end
```

You can replace it with this much cleaner approach:

```ruby
# New simple way
light = Stoplight('api-call', skipped_errors: [ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid])
```

The new system is way more explicit about what's happening, and you don't have to worry about accidentally forgetting 
to call the handler or raising the error in the right places.

### Fallbacks Work Differently Now

Fallbacks have moved from being configured on the light instance to being passed directly to the run method. This might 
seem like a small change, but it's actually pretty powerful and solves a real problem we've observed in production 
codebases. When fallbacks were configured on the light instance, you'd often end up with the same circuit breaker 
protecting multiple different operations, but each operation would need its own fallback strategy. This led to either 
duplicated light configurations or inappropriate fallbacks being applied to the wrong operations. The new approach 
makes each operation's fallback explicit and prevents configuration contamination between different use cases.

Instead of configuring fallbacks upfront like this:

```ruby
# Old way
light = Stoplight("Payment Gateway")
        .with_fallback { |error| handle_payment_failure(error) }
result = light.run { process_payment }
```

You now pass the fallback directly to the run method:

```ruby
# New way
light = Stoplight('Payment Gateway') 
result = light.run(->(error) { handle_payment_failure(error) }) { process_payment }
```

This makes it much clearer which fallback belongs to which operation, and you can easily have the same circuit breaker 
protect multiple operations with completely different fallback behaviors.

### Redis Data Gets a Fresh Start

Here's the one change that doesn't require any code updates but is worth knowing about: Stoplight 5.0 uses completely 
new Redis data structures that aren't compatible with the old version. We didn't make this change lightly - the old 
data structures were becoming a bottleneck for the new features we wanted to build, especially around better 
distributed coordination and more sophisticated error tracking. The new structures use Lua scripting for atomic 
operations, which eliminates race conditions in distributed environments and provides much better performance. 
Unfortunately, there was no practical way to migrate the old data format without significant complexity and potential 
data corruption risks, so we opted for a clean break.

For most applications, this isn't a big deal since circuit breakers are designed to adapt quickly to current conditions 
anyway. But if you have circuit breakers that take a long time to fail and you're upgrading during a period when your 
dependencies are already having issues, you might want to plan your deployment timing accordingly.

The old Redis data won't be deleted, so if you really need to reference historical information for debugging purposes, 
it'll still be there. But Stoplight will ignore it completely and start fresh.

### Testing Your Migration

Once you've made all these changes, definitely test everything thoroughly in a staging environment that mirrors your 
production setup. Pay special attention to how your circuit breakers behave under load and make sure your error 
classification is working the way you expect.

The new error handling system is much more explicit, but that also means if you get the configuration wrong, it'll be 
more obvious what's happening (which is actually a good thing).

### Getting Help

If you run into any issues during the migration, don't hesitate to post a message to our [Discussions forum]. We've 
tried to make the error messages as clear as possible when something's misconfigured. The new APIs are much more 
consistent and predictable once you get used to them.

Overall, while this upgrade does require some work upfront, the end result is a much cleaner and more reliable circuit 
breaker setup that should serve you well going forward.

## Stoplight 4.0

### Notifiers have dropped!

With this release, we've officially moved all third-party notifiers out of Stoplight.
The only notifiers that remain to be in the Stoplight distribution are:

* `Stoplight::Notifier::IO`
* `Stoplight::Notifier::Logger`

#### Why was this decision made?

We've taken this decision for the following technical reasons:

* We wanted to free the maintainers from supporting all the different notifiers, relying more on 
  the community to maintain them based on broad interest.
* Moving notifiers into separate gems allow to solve the dependency issues once and for all.
  The notifiers gems will be able to automatically pull any necessary dependency, without having to 
  rely on the developer to do so.
* With the community-supported notifiers, we can solve the third-party services compatibility issue. Such services 
  arise and go and Stoplight should not depend on their lifecycle.

#### So, what does this mean for me?

Unfortunately, we cannot support all the possible notifiers. 

* All the notifiers relying on third-party services have been dropped.
* We implemented the Sentry notifier as an external [stoplight-sentry] gem. You can use it as a reference implementation.
* We added a [Community-supported notifiers] section and encourage you to contribute by adding your notifiers.

#### All right! What should I change in my code immediately after upgrading?

* If you just use the default, `Stoplight::Notifier::IO`, or `Stoplight::Notifier::Logger` notifiers, then you 
  don't need to do anything!
* Otherwise, you many need to find a third-party notifier:

```ruby
# Gemfile
gem 'sentry'
gem 'stoplight'
gem 'stoplight-sentry'

# Code 
Stoplight.default_notifiers += [Stoplight::Sentry::Notifier.new(Sentry)]
```
* If you cannot find a notifier gem, you may need to implement your own. Consider checking the 
  [How to implement your own notifier?]  guide which contains all the information needed to implement a notifier. You 
  can use [dropped notifiers] for the inspiration.

### Stoplight() interface has changed

We moved block argument from the `Stoplight()` function to the `#run` method.

#### Why was this decision made?

We aim to make Stoplight's configuration sharable across the code. Due to this change, it's possible to run 
different code blocks with the same Stoplight configuration:

```ruby
light = Stoplight('http-api').with_cool_off_time(300)
light.run { call_this }
light.run { call_that }
```

Another benefit is that now you can easily inspect the status of the circuit breaker [without passing an empty block]:  

```ruby
light.color 
```

#### So, what does this mean for me?

Stoplight 4.0 supports both an old and a new interface. However, the old interface is deprecated. To 
update to Stoplight 5.0, you will need to switch to the new syntax.
 
```diff
- Stoplight('example') { 1 / 0 }.run
+ Stoplight('example').run { 1 / 0 } 
```

### Stoplight::Light becomes private

This class has always considered private but some developers preferred to use `Stoplight::Light#new` instead of 
`Stoplight()`. In the next major release the use of `Stoplight::Light#new` will be forbidden. 

#### Why was this decision made?

We want to provide a simple, concise Stoplight interface. Having a single public interface guarantees users 
use it the right way.

#### So, what does this mean for me?

Any use of `Stoplight::Light` outside of Stoplight itself is deprecated in Stoplight 4.0. To update to the 
next major version (Stoplight 5.0), you will need to change a few things:

```diff
- Stoplight::Light.default_data_store = data_store
+ Stoplight.default_data_store = data_store
```

```diff
- Stoplight::Light.default_notifiers += [notifier]
+ Stoplight.default_notifiers += [notifier]
```

```diff
- Stoplight::Light.default_error_notifier = ->(*) {}
+ Stoplight.default_error_notifier = ->(*) {}
```

In case you prefer to check types in your specs, you may need to switch it from checking for `Stoplight::Light` class
to `Stoplight::CircuitBreaker`. The `Stoplight::CircuitBreaker` abstract module considered the only public interface. 

Under the hood, we use two slightly different implementations to provide a smooth transition to the new interface 
and to make it possible to pass Stoplight as a dependency.

#### All right! What should I change in my code immediately after upgrading?

You might encounter a few deprecation warnings, but you do not need to changes anything in your code in this release. 

### Change in Redis Data Structures

Redis Data store in Stoplight 4.0 uses a new data structure under the hood. 

#### Why was this decision made?

This decision was made to enable the implementation of error counting using a [sliding window] approach. This feature 
allows Stoplight to count only errors that have occurred recently.

#### So, what does this mean for me?

After upgrading to this version, Stoplight will not be aware of errors that occurred before the update.

#### All right! What should I change in my code immediately after upgrading?

Nothing. Stoplight will function as usual.

[stoplight-sentry]: https://github.com/bolshakov/stoplight-sentry
[Community-supported notifiers]: https://github.com/bolshakov/stoplight/tree/master#community-supported-notifiers
[How to implement your own notifier?]: https://github.com/bolshakov/stoplight/blob/master/lib/stoplight/notifier/generic.rb
[dropped notifiers]: https://github.com/bolshakov/stoplight/tree/v3.0.1/lib/stoplight/notifier
[without passing an empty block]: https://github.com/bolshakov/stoplight-admin/blob/9c9848eb94410e46b20972548f0863db224cb6da/lib/sinatra/stoplight_admin.rb#L30
[sliding window]: https://github.com/bolshakov/stoplight#custom-window-size
[systems]: https://github.com/bolshakov/stoplight/blob/master/docs/systems.md
[Discussions forum]: https://github.com/bolshakov/stoplight/discussions/categories/q-a
