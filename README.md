# [Stoplight][]

[![Version badge][]][version]
[![Build badge][]][build]
[![Coverage badge][]][coverage]
[![Climate badge][]][climate]

Stoplight is traffic control for code. It's an implementation of the circuit
breaker pattern in Ruby.

---

:warning:️ You're currently browsing the documentation for Stoplight 4.x. If you're looking for
the documentation of the previous version 3.x, you can find it [here](https://github.com/bolshakov/stoplight/tree/release/v3.x).

Does your code use unreliable systems, like a flaky database or a spotty web
service? Wrap calls to those up in stoplights to prevent them from affecting
the rest of your application.

Check out [stoplight-admin][] for controlling your stoplights.

- [Installation](#installation)
- [Basic Usage](#basic-usage)
  - [Custom Errors](#custom-errors)
  - [Custom Fallback](#custom-fallback)
  - [Custom Threshold](#custom-threshold)
  - [Custom Window Size](#custom-window-size)
  - [Custom Cool Off Time](#custom-cool-off-time)
  - [Rails](#rails)
- [Setup](#setup)
  - [Data Store](#data-store)
    - [Redis](#redis)
  - [Notifiers](#notifiers)
    - [IO](#io)
    - [Logger](#logger)
    - [Community-supported Notifiers](#community-supported-notifiers)
    - [How to Implement Your Own Notifier?](#how-to-implement-your-own-notifier)
  - [Rails](#rails-1)
- [Advanced Usage](#advanced-usage)
  - [Locking](#locking)
  - [Testing](#testing)
- [Maintenance Policy](#maintenance-policy)
- [Credits](#credits)

## Installation

Add it to your Gemfile:

```ruby
gem 'stoplight'
```

Or install it manually:

```sh
$ gem install stoplight
```

Stoplight uses [Semantic Versioning][]. Check out [the change log][] for a
detailed list of changes.

## Basic Usage

To get started, create a stoplight:

```ruby
light = Stoplight('example-pi')
```

Then you can run it with a block of code and it will return the result of calling the block. This is
the green state. (The green state corresponds to the closed state for circuit breakers.)

```ruby
light.run { 22.0 / 7 }
# => 3.142857142857143
light.color
# => "green"
```

If everything goes well, you shouldn't even be able to tell that you're using a
stoplight. That's not very interesting though, so let's make stoplight fail.

When you run it, the error will be recorded and passed through. After
running it a few times, the stoplight will stop trying and fail fast. This is
the red state. (The red state corresponds to the open state for circuit
breakers.)

```ruby
light = Stoplight('example-zero')
# => #<Stoplight::CircuitBreaker:...>
light.run { 1 / 0 }
# ZeroDivisionError: divided by 0
light.run { 1 / 0 }
# ZeroDivisionError: divided by 0
light.run { 1 / 0 }
# Switching example-zero from green to red because ZeroDivisionError divided by 0
# ZeroDivisionError: divided by 0
light.run { 1 / 0 }
# Stoplight::Error::RedLight: example-zero
light.color
# => "red"
```

When the Stoplight changes from green to red, it will notify every configured
notifier. See [the notifiers section][] to learn more about notifiers.

The stoplight will move into the yellow state after being in the red state for
a while. (The yellow state corresponds to the half open state for circuit
breakers.) To configure how long it takes to switch into the yellow state,
check out [the cool off time section][] When stoplights are yellow, they will
try to run their code. If it fails, they'll switch back to red. If it succeeds,
they'll switch to green.

By default, stoplights re-raise errors when they're green. When they're
red, they raise a `Stoplight::Error::RedLight` error. You can provide a
fallback that will be called in both of these cases. It will be passed with an instance of the
error if the light was green.

```ruby
fallback = ->(e) {  e; 'default' }
light = Stoplight('example-fallback')
# => #<Stoplight::CircuitBreaker:..>
light.run(fallback) { 1 / 0 } # passes an instance of error into fallback
# #<ZeroDivisionError: divided by 0>
# => "default"
light.run(fallback) { 1 / 0 } # passes an instance of error into fallback
# #<ZeroDivisionError: divided by 0>
# => "default"
light.run(fallback) { 1 / 0 } # passes an instance of error into fallback
# Switching example-fallback from green to red because ZeroDivisionError divided by 0
# #<ZeroDivisionError: divided by 0>
# => "default"
light.run(fallback) { 1 / 0 } # passes `nil` to into fallback, since there is no error
# nil
# => "default"
```

### Error Handling

Stoplight needs to determine which errors should change the light's state 
and which shouldn't. For this purpose, Stoplight provides two 
methods: `with_tracked_errors` and `with_skipped_errors`.

#### Default Behavior

By default, Stoplight tracks all `StandardError` exceptions, but automatically 
skips the following errors:

```
NoMemoryError,
ScriptError,
SecurityError,
SignalException,
SystemExit,
SystemStackError
```

#### Custom Error Configuration

Some errors shouldn't cause your Stoplight to move into the red state. Usually 
these are handled elsewhere in your stack and don't represent real failures. 
A good example is `ActiveRecord::RecordNotFound`. 

To prevent specific errors from changing the state of your stoplight, use `#with_skipped_errors`:

```ruby
light = Stoplight('example-not-found')
  .with_skipped_errors(ActiveRecord::RecordNotFound)
# => #<Stoplight::Light:...>

light.run { User.find(123) }
# ActiveRecord::RecordNotFound: Couldn't find User with ID=123
light.run { User.find(123) }
# ActiveRecord::RecordNotFound: Couldn't find User with ID=123
light.run { User.find(123) }
# ActiveRecord::RecordNotFound: Couldn't find User with ID=123

light.color
# => "green"
```

You can add multiple errors to skip:

```ruby
light = Stoplight('example-custom')
  .with_skipped_errors(
    ActiveRecord::RecordNotFound, 
    ActiveRecord::RecordInvalid,
    ValidationError
  )
```

To explicitly specify which errors should be tracked (those that will 
change the light's state), use `#with_tracked_errors`:

```ruby
light = Stoplight('example-api')
  .with_tracked_errors(
    NetworkError,
    Timeout::Error,
    ApiRateLimitError
  )
```

#### Interaction Between Tracked and Skipped Errors

When both `#with_tracked_errors` and `#with_skipped_errors` are used:

* Errors in the `skipped_errors` list take precedence - they will never change the light's color
* Errors in the `tracked_errors` list will be counted toward changing the light from green to yellow to red
* Errors in neither list will follow the default behavior (tracked unless they're in the built-in skip list)

#### Advanced Usage: Triple Equals Operator

Both methods use triple equals operator (`===`) for comparison, allowing for flexible error matching:

```ruby
light = Stoplight('flexible-matching')
  .with_tracked_errors(
    ->(e) { e.is_a?(ApiError) && e.status >= 500 },
    ->(e) { e.message.include?("rate limit exceeded") }
  )
```

This allows for complex error classification based on error properties 
beyond just their class.

### Custom Threshold

Some bits of code might be allowed to fail more or less frequently than others.
You can configure this by setting a custom threshold.

```ruby
light = Stoplight('example-threshold')
  .with_threshold(1)
# => #<Stoplight::CircuitBreaker:...>
light.run { fail }
# Switching example-threshold from green to red because RuntimeError
# RuntimeError:
light.run { fail }
# Stoplight::Error::RedLight: example-threshold
```

The default threshold is `3`.

### Custom Window Size

By default, all recorded failures, regardless of the time these happen, will count to reach
the threshold (hence turning the light to red). If needed, a window size can be set,
meaning you can control how many errors per period of time will count to reach the red
state.

By default, every recorded failure contributes to reaching the threshold, regardless of when it occurs, 
causing the stoplight to turn red. By configuring a custom window size, you control how errors are 
counted within a specified time frame. Here's how it works:

Let's say you set the window size to 2 seconds:

 ```ruby
window_size_in_seconds = 2

light = Stoplight('example-threshold')
  .with_window_size(window_size_in_seconds)
  .with_threshold(1) #=> #<Stoplight::CircuitBreaker:...>

light.run { 1 / 0 } #=> #<ZeroDivisionError: divided by 0>
sleep(3)
light.run { 1 / 0 }
 ```

Without the window size configuration, the second `light.run { 1 / 0 }` call will result in a
`Stoplight::Error::RedLight` exception being raised, as the stoplight transitions to the red state 
after the first call. With a sliding window of 2 seconds, only the errors that occur within the latest
2 seconds are considered. The first error causes the stoplight to turn red, but after 3 seconds 
(when the second error occurs), the window has shifted, and the stoplight switches to green state 
causing the error to raise again. This provides a way to focus on the most recent errors.

The default window size is infinity, so all failures counts.

### Custom Cool Off Time

Stoplights will automatically attempt to recover after a certain amount of
time. A light in the red state for longer than the cool off period will
transition to the yellow state. This cool off time is customizable.

```ruby
light = Stoplight('example-cool-off')
  .with_cool_off_time(1)
# => #<Stoplight::CircuitBreaker:...>
light.run { fail }
# RuntimeError:
light.run { fail }
# RuntimeError:
light.run { fail }
# Switching example-cool-off from green to red because RuntimeError
# RuntimeError:
sleep(1)
# => 1
light.color
# => "yellow"
light.run { fail }
# RuntimeError:
```

The default cool off time is `60` seconds. To disable automatic recovery, set
the cool off to `Float::INFINITY`. To make automatic recovery instantaneous,
set the cool off to `0` seconds. Note that this is not recommended, as it
effectively replaces the red state with yellow.

### Direct Usage

In addition to the builder interface, you can directly create a stoplight using 
the `Stoplight()` method. This method allows you to configure the stoplight with a name and 
optional settings in a single step.

```ruby
light = Stoplight('example-direct', cool_off_time: 10, threshold: 5)

light.run { 1 / 0 }
# ZeroDivisionError: divided by 0
light.color
# => "red"
```

The `Stoplight()` method accepts the following settings:

* `:cool_off_time` - The time to wait before resetting the circuit breaker.
* `:data_store` - The data store to use for storing state.
* `:error_notifier` - A proc to handle error notifications.
* `:notifiers` - A list of notifiers to use.
* `:threshold` - The failure threshold to trip the circuit breaker.
* `:window_size` - The size of the rolling window for failure tracking.
* `:tracked_errors` - A list of errors to track.
* `:skipped_errors` - A list of errors to skip.

This approach is useful for quickly setting up a stoplight without chaining multiple configuration methods.

### Rails

Stoplight was designed to wrap Rails actions with minimal effort. Here's an
example configuration:

```ruby
class ApplicationController < ActionController::Base
  around_action :stoplight

  private

  def stoplight(&block)
    Stoplight("#{params[:controller]}##{params[:action]}")
      .run(-> { render(nothing: true, status: :service_unavailable) }, &block)
  end
end
```

## Setup

### Data store

Stoplight uses an in-memory data store out of the box.

```ruby
require 'stoplight'
# => true
Stoplight.default_data_store
# => #<Stoplight::DataStore::Memory:...>
```

If you want to use a persistent data store, you'll have to set it up. Currently
the only supported persistent data store is Redis.

#### Redis

Make sure you have [the Redis gem][] installed before configuring Stoplight.

```ruby
require 'redis'
# => true
redis = Redis.new
# => #<Redis client ...>
data_store = Stoplight::DataStore::Redis.new(redis)
# => #<Stoplight::DataStore::Redis:...>
Stoplight.default_data_store = data_store
# => #<Stoplight::DataStore::Redis:...>
```

### Notifiers

Stoplight sends notifications to standard error by default.

``` rb
Stoplight.default_notifiers
# => [#<Stoplight::Notifier::IO:...>]
```

If you want to send notifications elsewhere, you'll have to set them up.

#### IO

Stoplight can notify not only into STDOUT, but into any IO object. You can configure 
the `Stoplight::Notifier::IO` notifier for that.

```ruby
require 'stringio'

io = StringIO.new
# => #<StringIO:...>
notifier = Stoplight::Notifier::IO.new(io)
# => #<Stoplight::Notifier::IO:...>
Stoplight.default_notifiers += [notifier]
# => [#<Stoplight::Notifier::IO:...>, #<Stoplight::Notifier::IO:...>]
```

#### Logger

Stoplight can be configured to use [the Logger class][] from the standard
library.

```ruby
require 'logger'
# => true
logger = Logger.new(STDERR)
# => #<Logger:...>
notifier = Stoplight::Notifier::Logger.new(logger)
# => #<Stoplight::Notifier::Logger:...>
Stoplight.default_notifiers += [notifier]
# => [#<Stoplight::Notifier::IO:...>, #<Stoplight::Notifier::Logger:...>]
```

#### Community-supported Notifiers

* [stoplight-sentry]
* [stoplight-honeybadger](https://github.com/qoqa/stoplight-honeybadger)

You you want to implement your own notifier, the following section contains all the required information.

Pull requests to update this section are welcome.

#### How to implement your own notifier?

A notifier has to implement the `Stoplight::Notifier::Base` interface:

```ruby
def notify(light, from_color, to_color, error)
  raise NotImplementedError
end
```

For convenience, you can use the `Stoplight::Notifier::Generic` module. It takes care of
the message formatting, and you have to implement only the `put` method, which takes message sting as an argument:

```ruby 
class IO < Stoplight::Notifier::Base
  include Generic
   
  private
    
  def put(message)
    @object.puts(message)
  end
end
```

### Rails

Stoplight is designed to work seamlessly with Rails. If you want to use the
in-memory data store, you don't need to do anything special. If you want to use
a persistent data store, you'll need to configure it. Create an initializer for
Stoplight:

```ruby
# config/initializers/stoplight.rb
require 'stoplight'
Stoplight.default_data_store = Stoplight::DataStore::Redis.new(...)
Stoplight.default_notifiers += [Stoplight::Notifier::Logger.new(Rails.logger)]
```

## Advanced usage

### Locking

Although stoplights can operate on their own, occasionally you may want to
override the default behavior. You can lock a light using `#lock(color)` method.
Color should be either `Stoplight::Color::GREEN` or ``Stoplight::Color::RED``.

```ruby
light = Stoplight('example-locked')
# => #<Stoplight::CircuitBreaker:..>
light.run { true }
# => true
light.lock(Stoplight::Color::RED)
# => #<Stoplight::CircuitBreaker:..>
light.run { true } 
# Stoplight::Error::RedLight: example-locked
```

**Code in locked red lights may still run under certain conditions!** If you
have configured a custom data store and that data store fails, Stoplight will
switch over to using a blank in-memory data store. That means you will lose the
locked state of any stoplights.

You can go back to using the default behavior by unlocking the stoplight using `#unlock`.

```ruby
light.unlock
# => #<Stoplight::CircuitBreaker:..>
```

### Testing

Stoplights typically work as expected without modification in test suites.
However there are a few things you can do to make them behave better. If your
stoplights are spewing messages into your test output, you can silence them
with a couple configuration changes.

```ruby
Stoplight.default_error_notifier = -> _ {}
Stoplight.default_notifiers = []
```

If your tests mysteriously fail because stoplights are the wrong color, you can
try resetting the data store before each test case. For example, this would
give each test case a fresh data store with RSpec.

```ruby
before(:each) do
  Stoplight.default_data_store = Stoplight::DataStore::Memory.new
end
```

Sometimes you may want to test stoplights directly. You can avoid resetting the
data store by giving each stoplight a unique name.

```ruby
stoplight = Stoplight("test-#{rand}")
```

## Maintenance Policy

Stoplight supports the latest three minor versions of Ruby, which currently are: `3.2.x`, `3.3.x`, and `3.4.x`. Changing
the minimum supported Ruby version is not considered a breaking change.
We support the current stable Redis version (`7.4.x`) and the latest release of the previous major version (`6.2.x`)

## Credits

Stoplight is brought to you by [@camdez][] and [@tfausak][] from [@OrgSync][]. [@bolshakov][] is the current 
maintainer of the gem. A [complete list of contributors][] is available on GitHub. We were inspired by
Martin Fowler's [CircuitBreaker][] article. 

Stoplight is licensed under [the MIT License][].

[Stoplight]: https://github.com/bolshakov/stoplight
[Version badge]: https://img.shields.io/gem/v/stoplight.svg?label=version
[version]: https://rubygems.org/gems/stoplight
[Build badge]: https://github.com/bolshakov/stoplight/workflows/Specs/badge.svg
[build]: https://github.com/bolshakov/stoplight/actions?query=branch%3Amaster
[Coverage badge]: https://img.shields.io/coveralls/bolshakov/stoplight/master.svg?label=coverage
[coverage]: https://coveralls.io/r/bolshakov/stoplight
[Climate badge]: https://api.codeclimate.com/v1/badges/3451c2d281ffa345441a/maintainability
[climate]: https://codeclimate.com/github/bolshakov/stoplight
[stoplight-admin]: https://github.com/bolshakov/stoplight-admin
[Semantic Versioning]: http://semver.org/spec/v2.0.0.html
[the change log]: CHANGELOG.md
[the notifiers section]: #notifiers
[the cool off time section]: #custom-cool-off-time
[the Redis gem]: https://rubygems.org/gems/redis
[the Bugsnag gem]: https://rubygems.org/gems/bugsnag
[the Honeybadger gem]: https://rubygems.org/gems/honeybadger
[the Logger class]: http://ruby-doc.org/stdlib-2.2.3/libdoc/logger/rdoc/Logger.html
[the Rollbar gem]: https://rubygems.org/gems/rollbar
[the Sentry gem]: https://rubygems.org/gems/sentry-raven
[the Slack gem]: https://rubygems.org/gems/slack-notifier
[the Pagerduty gem]: https://rubygems.org/gems/pagerduty
[@camdez]: https://github.com/camdez
[@tfausak]: https://github.com/tfausak
[@orgsync]: https://github.com/OrgSync
[@bolshakov]: https://github.com/bolshakov
[complete list of contributors]: https://github.com/bolshakov/stoplight/graphs/contributors
[CircuitBreaker]: http://martinfowler.com/bliki/CircuitBreaker.html
[the MIT license]: LICENSE.md
[stoplight-sentry]: https://github.com/bolshakov/stoplight-sentry
