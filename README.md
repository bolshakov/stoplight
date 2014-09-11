# [Stoplight][1]

[![Gem version][2]][3]
[![Build status][4]][5]
[![Coverage status][6]][7]
[![Quality status][8]][9]
[![Dependency status][10]][11]

Traffic control for code. An implementation of the circuit breaker pattern in
Ruby.

Check out [stoplight-admin][12] for controlling your stoplights.

- [Installation](#installation)
- [Setup](#setup)
  - [Data store](#data-store)
  - [Notifiers](#notifiers)
  - [Rails](#rails)
- [Usage](#usage)
  - [Mixin](#mixin)
  - [Custom errors](#custom-errors)
  - [Custom fallback](#custom-fallback)
  - [Custom threshold](#custom-threshold)
  - [Custom timeout](#custom-timeout)
  - [Rails](#rails-1)
- [Credits](#credits)

## Installation

Add it to your Gemfile:

``` rb
gem 'stoplight', '~> 0.3.0'
```

Or install it manually:

``` sh
$ gem install stoplight
```

This project uses [Semantic Versioning][13].

## Setup

### Data store

Stoplight uses an in-memory data store out of the box.

``` irb
>> require 'stoplight'
=> true
>> Stoplight.data_store
=> #<Stoplight::DataStore::Memory:...>
```

If you want to use a persistent data store, you'll have to set it up. Currently
the only supported persistent data store is Redis. Make sure you have [the Redis
gem][14] installed before configuring Stoplight.

``` irb
>> require 'redis'
=> true
>> redis = Redis.new(url: 'redis://127.0.0.1:6379/0')
=> #<Redis:...>
>> data_store = Stoplight::DataStore::Redis.new(redis)
=> #<Stoplight::DataStore::Redis:...>
>> Stoplight.data_store = data_store
=> #<Stoplight::DataStore::Redis:...>
```

### Notifiers

Stoplight sends notifications to standard error by default.

``` irb
>> Stoplight.notifiers
=> [#<Stoplight::Notifier::StandardError:...>]
```

If you want to send notifications elsewhere, you'll have to set them up.
Currently the only other supported notifier is HipChat. Make sure you have [the
HipChat gem][15] installed before configuring Stoplight.

``` irb
>> require 'hipchat'
=> true
>> hipchat = HipChat::Client.new('token')
=> #<HipChat::Client:...>
>> notifier = Stoplight::Notifier::HipChat.new(hipchat, 'room')
=> #<Stoplight::Notifier::HipChat:...>
>> Stoplight.notifiers << notifier
=> [#<Stoplight::Notifier::StandardError:...>, #<Stoplight::Notifier::HipChat:...>]
```

### Rails

Stoplight is designed to work seamlessly with Rails. If you want to use the
in-memory data store, you don't need to do anything special. If you want to use
a persistent data store, you'll need to configure it. Create an initializer for
Stoplight:

``` rb
# config/initializers/stoplight.rb
require 'stoplight'
Stoplight.data_store = Stoplight::DataStore::Redis.new(...)
Stoplight.notifiers << Stoplight::Notifier::HipChat.new(...)
```

## Usage

To get started, create a stoplight:

``` irb
>> light = Stoplight::Light.new('example-1') { 22.0 / 7 }
=> #<Stoplight::Light:...>
```

Then you can run it and it will return the result of calling the block. This is
the green state.

``` irb
>> light.run
=> 3.142857142857143
>> light.green?
=> true
```

If everything goes well, you shouldn't even be able to tell that you're using a
stoplight. That's not very interesting though. Let's create a failing stoplight:

``` irb
>> light = Stoplight::Light.new('example-2') { 1 / 0 }
=> #<Stoplight::Light:...>
```

Now when you run it, the error will be recorded and passed through. After
running it a few times, the stoplight will stop trying and fail fast. This is
the red state.

``` irb
>> light.run
ZeroDivisionError: divided by 0
>> light.run
ZeroDivisionError: divided by 0
>> light.run
ZeroDivisionError: divided by 0
>> light.run
Switching example-2 from green to red.
Stoplight::Error::RedLight: example-2
>> light.red?
=> true
```

When the stoplight changes from green to red, it will notify every configured
notifier.

### Mixin

Since creating and running a stoplight is so common, we provide a mixin that
makes it easy.

``` irb
>> include Stoplight::Mixin
=> Object
>> stoplight('example-3') { 1.0 / 3 }
=> 0.3333333333333333
```

### Custom errors

Some errors shouldn't cause your stoplight to move into the red state. Usually
these are handled elsewhere in your stack and don't represent real failures. A
good example is `ActiveRecord::RecordNotFound`.

``` irb
>> light = Stoplight::Light.new('example-4') { User.find(123) }.
..   with_allowed_errors([ActiveRecord::RecordNotFound])
=> #<Stoplight::Light:...>
>> light.run
ActiveRecord::RecordNotFound: Couldn't find User with ID=123
>> light.run
ActiveRecord::RecordNotFound: Couldn't find User with ID=123
>> light.run
ActiveRecord::RecordNotFound: Couldn't find User with ID=123
>> light.green?
=> true
```

### Custom fallback

Instead of raising a `Stoplight::Error::RedLight` error when in the red state,
you can provide a block to be run. This is useful when there's a good default
value for the block.

``` irb
>> light = Stoplight::Light.new('example-5') { fail }.
..   with_fallback { [] }
=> #<Stoplight::Light:...>
>> light.run
RuntimeError:
>> light.run
RuntimeError:
>> light.run
RuntimeError:
>> light.run
=> []
```

### Custom threshold

Some bits of code might be allowed to fail more or less frequently than others.
You can configure this by setting a custom threshold in seconds.

``` irb
>> light = Stoplight::Light.new('example-6') { fail }.
..   with_threshold(1)
=> #<Stoplight::Light:...>
>> light.run
RuntimeError:
>> light.run
Stoplight::Error::RedLight: example-6
```

### Custom timeout

Stoplights will automatically attempt to recover after a certain amount of time.
A light in the red state for longer than the timeout will transition to the
yellow state. This timeout is customizable.

``` irb
>> light = Stoplight::Light.new('example-7') { fail }.
..   with_timeout(1)
=> #<Stoplight::Light:...>
>> light.run
RuntimeError:
>> light.run
RuntimeError:
>> light.run
RuntimeError:
>> light.run
Switching example-7 from green to red.
Stoplight::Error::RedLight: example-7
>> sleep(1)
=> 1
>> light.yellow?
=> true
>> light.run
RuntimeError:
```

Set the timeout to `-1` to disable automatic recovery.

### Rails

Stoplight was designed to wrap Rails actions with minimal effort. Here's an
example configuration:

``` rb
class ApplicationController < ActionController::Base
  around_action :stoplight
  private
  def stoplight(&block)
    Stoplight::Light.new("#{params[:controller]}##{params[:action]}", &block)
      .with_allowed_errors([ActiveRecord::RecordNotFound])
      .with_fallback { render(nothing: true, status: :service_unavailable) }
      .run
  end
end
```

## Credits

Stoplight is brought to you by [@camdez][16] and [@tfausak][17] from
[@OrgSync][18]. We were inspired by Martin Fowler's [CircuitBreaker][19]
article.

If this gem isn't cutting it for you, there are a few alternatives, including:
[circuit_b][20], [circuit_breaker][21], [simple_circuit_breaker][22], and
[ya_circuit_breaker][23].

[1]: https://github.com/orgsync/stoplight
[2]: https://badge.fury.io/rb/stoplight.svg
[3]: https://rubygems.org/gems/stoplight
[4]: https://travis-ci.org/orgsync/stoplight.svg
[5]: https://travis-ci.org/orgsync/stoplight
[6]: https://img.shields.io/coveralls/orgsync/stoplight.svg
[7]: https://coveralls.io/r/orgsync/stoplight
[8]: https://codeclimate.com/github/orgsync/stoplight/badges/gpa.svg
[9]: https://codeclimate.com/github/orgsync/stoplight
[10]: https://gemnasium.com/orgsync/stoplight.svg
[11]: https://gemnasium.com/orgsync/stoplight
[12]: https://github.com/orgsync/stoplight-admin
[13]: http://semver.org/spec/v2.0.0.html
[14]: https://rubygems.org/gems/redis
[15]: https://rubygems.org/gems/hipchat
[16]: https://github.com/camdez
[17]: https://github.com/tfausak
[18]: https://github.com/OrgSync
[19]: http://martinfowler.com/bliki/CircuitBreaker.html
[20]: https://github.com/alg/circuit_b
[21]: https://github.com/wsargent/circuit_breaker
[22]: https://github.com/soundcloud/simple_circuit_breaker
[23]: https://github.com/wooga/circuit_breaker
