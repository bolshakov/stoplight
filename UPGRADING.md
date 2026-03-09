## Stoplight 5.0 

Stoplight 5.0 introduces several breaking changes, so you'll need to set aside some time to update your code. The good 
news is that most of the changes are pretty straightforward, and once you're done, you'll have a much cleaner and 
more powerful setup.

Here's what you'll want to tackle during your upgrade. Don't worry if this looks like a lot - most of these are simple 
find-and-replace operations:

- [] Update global configuration to use the new block syntax
- [] Replace any remaining `Stoplight() {}` calls with `Stoplight().run {}`
- [] Convert error handlers to tracked/skipped error lists
- [] Move fallbacks from configuration to `#run` method calls
- [] Account for Stoplight state reset after deployment
- [] Test thoroughly in a staging environment

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
[Discussions forum]: https://github.com/bolshakov/stoplight/discussions/categories/q-a
