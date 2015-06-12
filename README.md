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
  - [Notifiers](#notifiers)
  - [Rails](#rails-1)
- [Advanced usage](#advanced-usage)
  - [Locking](#locking)
- [Credits](#credits)

## Installation

Add it to your Gemfile:

``` rb
gem 'stoplight', '~> 1.0'
```

Or install it manually:

``` sh
$ gem install stoplight --version '~> 1.0'
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

Then you can run it and it will return the result of calling the
block. This is the green state. (The green state corresponds to the
closed state for circuit breakers.)

``` rb
light.run
# => 3.142857142857143
light.color
# => "green"
```

If everything goes well, you shouldn't even be able to tell that
you're using a stoplight. That's not very interesting though. Let's
create a failing stoplight:

``` rb
light = Stoplight('example-2') { 1 / 0 }
# => #<Stoplight::Light:...>
```

Now when you run it, the error will be recorded and passed through.
After running it a few times, the stoplight will stop trying and
fail fast. This is the red state. (The red state corresponds to the
open state for circuit breakers.)

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

When the stoplight changes from green to red, it will notify every
configured notifier.

The stoplight will move into the yellow state after being in the
red state for a while. (The yellow state corresponds to the half
open state for circuit breakers.) When stoplights are yellow, they'll
try to run their code. If it fails, they'll switch back to red. If
it succeeds, they'll switch to green.

### Custom errors

Some errors shouldn't cause your stoplight to move into the red
state. Usually these are handled elsewhere in your stack and don't
represent real failures. A good example is `ActiveRecord::RecordNotFound`.

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

### Custom fallback

By default, stoplights will re-raise errors when they're green.
When they're red, they'll raise a `Stoplight::Error::RedLight`
error. You can provide a fallback that will be called in both of
these cases. It will be passed the error if the light was green.

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

Some bits of code might be allowed to fail more or less frequently
than others. You can configure this by setting a custom threshold
in seconds.

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

### Custom timeout

Stoplights will automatically attempt to recover after a certain
amount of time. A light in the red state for longer than the timeout
will transition to the yellow state. This timeout is customizable.

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

Set the timeout to `-1` to disable automatic recovery.

### Rails

Stoplight was designed to wrap Rails actions with minimal effort.
Here's an example configuration:

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

If you want to use a persistent data store, you'll have to set it
up. Currently the only supported persistent data store is Redis.
Make sure you have [the Redis gem][] installed before configuring
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

If you want to send notifications elsewhere, you'll have to set
them up. Currently the only other supported notifier is HipChat.
Make sure you have [the HipChat gem][] installed before configuring
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

### Rails

Stoplight is designed to work seamlessly with Rails. If you want
to use the in-memory data store, you don't need to do anything
special. If you want to use a persistent data store, you'll need
to configure it. Create an initializer for Stoplight:

``` rb
# config/initializers/stoplight.rb
require 'stoplight'
Stoplight::Light.default_data_store = Stoplight::DataStore::Redis.new(...)
Stoplight::Light.default_notifiers += [Stoplight::Notifier::HipChat.new(...)]
```

## Advanced usage

### Locking

Although stoplights can operate on their own, occasionally you may
want to override the default behavior. You can lock a light in
either the green or red state using `set_state`.

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

**Code in locked red lights may still run under certain conditions!**
If you have configured a custom data store and that data store
fails, Stoplight will switch over to using a blank in-memory data
store. That means you will lose the locked state of any stoplights.

## Credits

Stoplight is brought to you by [@camdez][] and [@tfausak][] from [@OrgSync][].
A [complete list of contributors][] is available on GitHub. We were inspired by
Martin Fowler's [CircuitBreaker][] article.

Stoplight is licensed under [the MIT License][].

[stoplight]: https://github.com/orgsync/stoplight
[version]: https://img.shields.io/gem/v/stoplight.svg?label=version&style=flat-square
[build]: https://img.shields.io/travis/orgsync/stoplight/master.svg?label=build&style=flat-square
[grade]: https://img.shields.io/badge/grade-A-brightgreen.svg?style=flat-square
[coverage]: https://img.shields.io/coveralls/orgsync/stoplight/master.svg?label=coverage&style=flat-square
[climate]: https://img.shields.io/codeclimate/github/orgsync/stoplight.svg?label=climate&style=flat-square
[dependencies]: https://img.shields.io/gemnasium/orgsync/stoplight.svg?label=dependencies&style=flat-square
[stoplight-admin]: https://github.com/orgsync/stoplight-admin
[semantic versioning]: http://semver.org/spec/v2.0.0.html
[the change log]: CHANGELOG.md
[the redis gem]: https://rubygems.org/gems/redis
[the hipchat gem]: https://rubygems.org/gems/hipchat
[@camdez]: https://github.com/camdez
[@tfausak]: https://github.com/tfausak
[@orgsync]: https://github.com/OrgSync
[complete list of contributors]: https://github.com/orgsync/stoplight/graphs/contributors
[circuitbreaker]: http://martinfowler.com/bliki/CircuitBreaker.html
[the mit license]: LICENSE.md
