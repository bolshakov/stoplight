## Stoplight 5.0 

Stoplight 5.0 introduces several breaking changes designed to improve configuration consistency, simplify error 
handling, and improve performance. This guide will help you migrate from Stoplight 4.x to 5.0.

### Migration Checklist

- [] Update global configuration to use the new block syntax
- [] Replace any remaining Stoplight() {} calls with Stoplight().run {}
- [] Convert error handlers to tracked/skipped error lists
- [] Move fallbacks from configuration to #run method calls
- [] Account for Stoplight state reset after deployment
- [] Test thoroughly in a staging environment

### Global Configuration Redesign

Global configuration has moved from individual setters to a unified configuration block system for better consistency.

#### Why was this decision made?

We wanted to provide a more consistent and safer configuration experience:

* Eliminates race conditions caused by individual global setters
* Atomic configuration ensures all settings are applied together
* Enables advanced features like configuration inheritance and overrides
* More idiomatic Ruby following block-based configuration conventions
 
#### So, what does this mean for me?

You'll need to update your configuration code:

```diff
# Old way (Stoplight 4.x)
- Stoplight.default_data_store = Stoplight::DataStore::Redis.new(redis)
- Stoplight.default_notifiers += [Stoplight::Notifier::Logger.new(Rails.logger)]
- Stoplight.default_error_notifier = ->(error) { Bugsnag.notify(error) }

# New way (Stoplight 5.0)
+ Stoplight.configure do |config|
+   config.data_store = Stoplight::DataStore::Redis.new(redis)
+   config.notifiers += [Stoplight::Notifier::Logger.new(Rails.logger)]
+   config.error_notifier = ->(error) { Bugsnag.notify(error) }
+ end
```

> 📖 **Reference**: For more configuration options, check the Stoplight's [configuration documentation]

### Deprecated Interface Removal

The `Stoplight() {}` interface, deprecated in Stoplight 4.0, has been completely removed which enabled us 
to simplify the codebase and improve performance.

#### So, what does this mean for me?

All `Stoplight() {}` calls must be converted to use the `#run {}` interface.

```diff
- Stoplight('API Call') { ... }.run
+ Stoplight('API Call').run { ... }
```

> 📖 **Reference**: For detailed migration examples, see the [Stoplight 4.0 upgrade guide].

### Simplified Error Handling


The complex `#with_error_handler` callback has been replaced with explicit error classification using 
`#with_skipped_errors` and `#with_tracked_errors`.

#### Why was this decision made?

* Eliminates confusion about when to call handlers vs. raise errors
* Prevents configuration leakage between different circuit breakers
* Simpler API - just list error types instead of writing handler logic
* Explicit separation between counted and ignored errors

#### So, what does this mean for me?

Replace error handlers with error classification:

```diff 
# Old way
- light = Stoplight('api-call')
-   .with_error_handler do |error, handle|
-     if error.is_a?(ActiveRecord::RecordNotFound) || error.is_a?(ActiveRecord::RecordInvalid)
-       raise error  # Don't track this error
-     else
-       handle.call(error)  # Track this error
-     end
-   end

# New way
+ light = Stoplight('api-call')
+   .with_skipped_errors(ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid)
```

> 📖 **Reference**: See the Stoplight [error handling] documentation for more examples.

### Fallback Handling Changes

Fallbacks are now provided directly to the `#run` method as a parameter, rather than being configured on the 
light instance.

```ruby
light = Stoplight("Payment Gateway")

# Different operations with operation-specific fallbacks
light.run(-> { [] }) { get_invoices }
light.run(-> { 0 }) { get_credits }
```

#### Why was this decision made?

* Operation-specific fallbacks enable each protected operation can have its own fallback.
* Therefore, configuration can be reused without fallback contamination
* Makes it obvious which fallback belongs to which operation

#### So, what does this mean for me?

If you were using fallbacks, you'll need to update your code to pass the fallback directly to the `#run` method:

```diff
# Old way
- light = Stoplight("Payment Gateway")
-   .with_fallback { |error| handle_payment_failure(error) }
- result = light.run { process_payment }

# New way
+ light = Stoplight('payment') 
+ result = light.run(->(error) { handle_payment_failure(error) }) { process_payment }
```

### Redis Data Structure Changes

Stoplight 5.0 uses completely new Redis data structures that are incompatible with previous versions.

#### Why was this decision made?

The Redis data store has been completely rewritten with new, more efficient data structures to support the 
new features such as error rate tracking, more robust circuit breaker decision-making in distributed environments, 
and green lights visibility in the admin UI.

#### So, what does this mean for me?

After upgrading, Stoplight will not be aware of failures and state from the previous version. Your existing Redis data 
will be ignored (but not deleted), and lights will start fresh in the green state.

**No code changes are required** - the upgrade is automatic, but you'll lose historical failure data.

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
[configuration documentation]: https://github.com/bolshakov/stoplight?tab=readme-ov-file#configuration
[error handling]: https://github.com/bolshakov/stoplight?tab=readme-ov-file#error-handling
[Stoplight 4.0 upgrade guide]: https://github.com/bolshakov/stoplight/blob/master/UPGRADING.md#stoplight-interface-has-changed
