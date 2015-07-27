# [Stoplight][]

[![Version][]](https://rubygems.org/gems/stoplight)
[![Build][]](https://travis-ci.org/orgsync/stoplight)
[![Coverage][]](https://coveralls.io/r/orgsync/stoplight)
[![Grade][]](http://www.libgrader.com/libraries/ruby/stoplight)
[![Climate][]](https://codeclimate.com/github/orgsync/stoplight)
[![Dependencies][]](https://gemnasium.com/orgsync/stoplight)

Stoplight is traffic control for code. It's an implementation of the circuit
breaker pattern in Ruby.

---

Does your code use unreliable systems, like a flaky database or a spotty web
service? Wrap calls to those up in stoplights to prevent them from affecting
the rest of your application.

Check out [stoplight-admin][] for controlling your stoplights.

- [Installation](#installation)
- [Basic usage](#basic-usage)
  - [Custom errors](#custom-errors)
  - [Custom fallback](#custom-fallback)
  - [Custom threshold](#custom-threshold)
  - [Custom timeout](#custom-timeout)
  - [Rails](#rails)
- [Setup](#setup)
  - [Data store](#data-store)
    - [Redis](#redis)
  - [Notifiers](#notifiers)
    - [HipChat](#hipchat)
    - [Slack](#slack)
  - [Rails](#rails-1)
- [Advanced usage](#advanced-usage)
  - [Locking](#locking)
  - [Testing](#testing)
- [Credits](#credits)

## Installation

Add it to your Gemfile:

``` rb
gem 'stoplight', '~> 1.1'
```

Or install it manually:

``` sh
$ gem install stoplight --version '~> 1.1'
```

Stoplight uses [Semantic Versioning][]. Check out [the change log][] for a
detailed list of changes.

Stoplight works with all supported versions of Ruby (2.0 through 2.2).

## Basic usage

To get started, create a stoplight:

``` rb
light = Stoplight('example-1') { 22.0 / 7 }
# => #<Stoplight::Light:...>
```

Then you can run it and it will return the result of calling the block. This is
the green state. (The green state corresponds to the closed state for circuit
  breakers.)

``` rb
light.run
# => 3.142857142857143
light.color
# => "green"
```

If everything goes well, you shouldn't even be able to tell that you're using a
stoplight. That's not very interesting though, so let's create a failing
stoplight:

``` rb
light = Stoplight('example-2') { 1 / 0 }
# => #<Stoplight::Light:...>
```

Now when you run it, the error will be recorded and passed through. After
running it a few times, the stoplight will stop trying and fail fast. This is
the red state. (The red state corresponds to the open state for circuit
  breakers.)

``` rb
light.run
# ZeroDivisionError: divided by 0
light.run
# ZeroDivisionError: divided by 0
light.run
# Switching example-2 from green to red because ZeroDivisionError divided by 0
# ZeroDivisionError: divided by 0
light.run
# Stoplight::Error::RedLight: example-2
light.color
# => "red"
```

When the stoplight changes from green to red, it will notify every configured
notifier. See [the notifiers section][] to learn more about notifiers.

The stoplight will move into the yellow state after being in the red state for
a while. (The yellow state corresponds to the half open state for circuit
  breakers.) To configure how long it takes to switch into the yellow state,
  check out [the timeout section][] When stoplights are yellow, they will try
  to run their code. If it fails, they'll switch back to red. If it succeeds,
  they'll switch to green.

### Custom errors

Some errors shouldn't cause your stoplight to move into the red state. Usually
these are handled elsewhere in your stack and don't represent real failures. A
good example is `ActiveRecord::RecordNotFound`.

``` rb
light = Stoplight('example-3') { User.find(123) }
  .with_allowed_errors([ActiveRecord::RecordNotFound])
# => #<Stoplight::Light:...>
light.run
# ActiveRecord::RecordNotFound: Couldn't find User with ID=123
light.run
# ActiveRecord::RecordNotFound: Couldn't find User with ID=123
light.run
# ActiveRecord::RecordNotFound: Couldn't find User with ID=123
light.color
# => "green"
```

The following errors are always allowed: `NoMemoryError`, `ScriptError`,
`SecurityError`, `SignalException`, `SystemExit`, and `SystemStackError`.

### Custom fallback

By default, stoplights will re-raise errors when they're green. When they're
red, they'll raise a `Stoplight::Error::RedLight` error. You can provide a
fallback that will be called in both of these cases. It will be passed the
error if the light was green.

``` rb
light = Stoplight('example-4') { 1 / 0 }
  .with_fallback { |e| p e; 'default' }
# => #<Stoplight::Light:..>
light.run
# #<ZeroDivisionError: divided by 0>
# => "default"
light.run
# #<ZeroDivisionError: divided by 0>
# => "default"
light.run
# Switching example-4 from green to red because ZeroDivisionError divided by 0
# #<ZeroDivisionError: divided by 0>
# => "default"
light.run
# nil
# => "default"
```

### Custom threshold

Some bits of code might be allowed to fail more or less frequently than others.
You can configure this by setting a custom threshold.

``` rb
light = Stoplight('example-5') { fail }
  .with_threshold(1)
# => #<Stoplight::Light:...>
light.run
# Switching example-5 from green to red because RuntimeError
# RuntimeError:
light.run
# Stoplight::Error::RedLight: example-5
```

The default threshold is `3`.

### Custom timeout

Stoplights will automatically attempt to recover after a certain amount of
time. A light in the red state for longer than the timeout will transition to
the yellow state. This timeout is customizable.

``` rb
light = Stoplight('example-6') { fail }
  .with_timeout(1)
# => #<Stoplight::Light:...>
light.run
# RuntimeError:
light.run
# RuntimeError:
light.run
# Switching example-6 from green to red because RuntimeError
# RuntimeError:
sleep(1)
# => 1
light.color
# => "yellow"
light.run
# RuntimeError:
```

The default timeout is `60` seconds. To disable automatic recovery, set the
timeout to `Float::INFINITY`. To make automatic recovery instantaneous, set the
timeout to `0` seconds. Note that this is not recommended, as it effectively
replaces the red state with yellow.

### Rails

Stoplight was designed to wrap Rails actions with minimal effort. Here's an
example configuration:

``` rb
class ApplicationController < ActionController::Base
  around_action :stoplight

  private

  def stoplight(&block)
    Stoplight("#{params[:controller]}##{params[:action]}", &block)
      .with_allowed_errors([ActiveRecord::RecordNotFound])
      .with_fallback do |error|
        Rails.logger.error(error)
        render(nothing: true, status: :service_unavailable)
      end
      .run
  end
end
```

## Setup

### Data store

Stoplight uses an in-memory data store out of the box.

``` rb
require 'stoplight'
# => true
Stoplight::Light.default_data_store
# => #<Stoplight::DataStore::Memory:...>
```

If you want to use a persistent data store, you'll have to set it up. Currently
the only supported persistent data store is Redis.

#### Redis

Make sure you have [the Redis gem][] (`~> 3.2`) installed before configuring
Stoplight.

``` rb
require 'redis'
# => true
redis = Redis.new
# => #<Redis client ...>
data_store = Stoplight::DataStore::Redis.new(redis)
# => #<Stoplight::DataStore::Redis:...>
Stoplight::Light.default_data_store = data_store
# => #<Stoplight::DataStore::Redis:...>
```

### Notifiers

Stoplight sends notifications to standard error by default.

``` rb
Stoplight::Light.default_notifiers
# => [#<Stoplight::Notifier::IO:...>]
```

If you want to send notifications elsewhere, you'll have to set them up.
Currently the only supported notifiers are HipChat and Slack.

#### HipChat

Make sure you have [the HipChat gem][] (`~> 1.5`) installed before configuring
Stoplight.

``` rb
require 'hipchat'
# => true
hip_chat = HipChat::Client.new('token')
# => #<HipChat::Client:...>
notifier = Stoplight::Notifier::HipChat.new(hip_chat, 'room')
# => #<Stoplight::Notifier::HipChat:...>
Stoplight::Light.default_notifiers += [notifier]
# => [#<Stoplight::Notifier::IO:...>, #<Stoplight::Notifier::HipChat:...>]
```

#### Slack

Make sure you have [the Slack gem][] (`~> 1.2`) installed before configuring
Stoplight.

``` rb
require 'slack-notifier'
# => true
slack = Slack::Notifier.new('http://www.example.com/webhook-url')
# => #<Slack::Notifier:...>
notifier = Stoplight::Notifier::Slack.new(slack)
# => #<Stoplight::Notifier::Slack:...>
Stoplight::Light.default_notifiers += [notifier]
# => [#<Stoplight::Notifier::IO:...>, #<Stoplight::Notifier::Slack:...>]
```

### Rails

Stoplight is designed to work seamlessly with Rails. If you want to use the
in-memory data store, you don't need to do anything special. If you want to use
a persistent data store, you'll need to configure it. Create an initializer for
Stoplight:

``` rb
# config/initializers/stoplight.rb
require 'stoplight'
Stoplight::Light.default_data_store = Stoplight::DataStore::Redis.new(...)
Stoplight::Light.default_notifiers += [Stoplight::Notifier::HipChat.new(...)]
```

## Advanced usage

### Locking

Although stoplights can operate on their own, occasionally you may want to
override the default behavior. You can lock a light in either the green or red
state using `set_state`.

``` rb
light = Stoplight('example-7') { true }
# => #<Stoplight::Light:..>
light.run
# => true
light.data_store.set_state(light, Stoplight::State::LOCKED_RED)
# => "locked_red"
light.run
# Stoplight::Error::RedLight: example-7
```

**Code in locked red lights may still run under certain conditions!** If you
have configured a custom data store and that data store fails, Stoplight will
switch over to using a blank in-memory data store. That means you will lose the
locked state of any stoplights.

You can go back to using the default behavior by unlocking the stoplight.

``` rb
light.data_store.set_state(light, Stoplight::State::UNLOCKED)
```

### Testing

Stoplights typically work as expected without modification in test suites.
However there are a few things you can do to make them behave better. If your
stoplights are spewing messages into your test output, you can silence them
with a couple configuration changes.

``` rb
Stoplight::Light.default_error_notifier = -> _ {}
Stoplight::Light.default_notifiers = []
```

If your tests mysteriously fail because stoplights are the wrong color, you can
try resetting the data store before each test case. For example, this would
give each test case a fresh data store with RSpec.

``` rb
before(:each) do
  Stoplight::Light.default_data_Store = Stoplight::DataStore::Memory.new
end
```

Sometimes you may want to test stoplights directly. You can avoid resetting the
data store by giving each stoplight a unique name.

``` rb
stoplight = Stoplight("test-#{rand}") { ... }
```

## Credits

Stoplight is brought to you by [@camdez][] and [@tfausak][] from [@OrgSync][].
A [complete list of contributors][] is available on GitHub. We were inspired by
Martin Fowler's [CircuitBreaker][] article.

Stoplight is licensed under [the MIT License][].

[stoplight]: https://github.com/orgsync/stoplight
[version]: https://img.shields.io/gem/v/stoplight.svg?label=version
[build]: https://img.shields.io/travis/orgsync/stoplight/master.svg?label=build
[grade]: https://img.shields.io/badge/grade-A-brightgreen.svg
[coverage]: https://img.shields.io/coveralls/orgsync/stoplight/master.svg?label=coverage
[climate]: https://img.shields.io/codeclimate/github/orgsync/stoplight.svg?label=climate
[dependencies]: https://img.shields.io/gemnasium/orgsync/stoplight.svg?label=dependencies
[stoplight-admin]: https://github.com/orgsync/stoplight-admin
[semantic versioning]: http://semver.org/spec/v2.0.0.html
[the change log]: CHANGELOG.md
[the notifiers section]: #notifiers
[the timeout section]: #custom-timeout
[the redis gem]: https://rubygems.org/gems/redis
[the hipchat gem]: https://rubygems.org/gems/hipchat
[the slack gem]: https://rubygems.org/gems/slack-notifier
[@camdez]: https://github.com/camdez
[@tfausak]: https://github.com/tfausak
[@orgsync]: https://github.com/OrgSync
[complete list of contributors]: https://github.com/orgsync/stoplight/graphs/contributors
[circuitbreaker]: http://martinfowler.com/bliki/CircuitBreaker.html
[the mit license]: LICENSE.md
