## Stoplight 4.0

### Notifiers have been dropped

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
* We implemented the Sentry notifier as an external [stoplight-sentry] gem.
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

The old interface is deprecated. To update to the next major version, you will need to switch to a new syntax.
 
```diff
- Stoplight('example') { 1 / 0}.run
+ Stoplight('example').run { 1 / 0} 
```

### Stoplight::Light becomes private

This class has always considered private but some people preferred to use `Stoplight::Light#new` instead of 
`Stoplight()`. In the next major release the use of `Stoplight::Light#new` will be forbidden. 

#### Why was this decision made?

We want to provide a simple, concise Stoplight interface. Having a single interface guarantees users 
use it the right way.

#### So, what does this mean for me?

Any use of `Stoplight::Light` outside of Stoplight itself is deprecated. To update to the next major version, you 
will need to change a few things:

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



[stoplight-sentry]: https://github.com/bolshakov/stoplight-sentry
[Community-supported notifiers]: https://github.com/bolshakov/stoplight/tree/master#community-supported-notifiers
[How to implement your own notifier?]: https://github.com/bolshakov/stoplight/tree/master#how-to-implement-your-own-notifier
[dropped notifiers]: https://github.com/bolshakov/stoplight/tree/v3.0.1/lib/stoplight/notifier
[without passing an empty block]: https://github.com/bolshakov/stoplight-admin/blob/9c9848eb94410e46b20972548f0863db224cb6da/lib/sinatra/stoplight_admin.rb#L30
