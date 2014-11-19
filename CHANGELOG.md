# Changelog

This project uses [Semantic Versioning][1].

- Fixed a logic bug that incorrectly determined red lights to be yellow.

## v0.5.0 (2014-11-19)

- Data stores and notifiers can be configured on a per-stoplight basis. This
  allows stoplights to use stoplights internally.
- Stoplights use stoplights internally to wrap calls to data stores and
  notifiers. This means they gracefully handle either going down.
- Data stores only store failures and states. Also failures are stored in a ring
  buffer. This drastically reduces the amount of data stored.
- Stoplights will use the fallback (if it's given) when they fail while they're
  green. This means they won't re-raise exceptions if you provide a fallback.
- Stoplights pass the error to their notifiers when transitioning from green to
  red.

## v0.4.1 (2014-10-03)

- Fixed a bug that caused green to red notifications to sometimes not be sent.

## v0.4.0 (2014-09-17)

- Made stoplights handle failing notifiers by logging the failure to standard
  error.
- Made stoplights automatically fall back to a fresh in-memory data store if the
  primary store is unavailable.
- Generalized `Stoplight::Notifier::StandardError` into
  `Stoplight::Notifier::IO`.
- Changed notification format from a string to a lambda. It accepts the same
  parameters that the format string accepted.
- Updated `Stoplight::Notifier::Base#notify` to accept three parameters (the
  light, the before color, and the after color) instead of just one parameter
  (the message).
- Prevented setting non-positive thresholds.
- Removed `Stoplight::Mixin`.

## v0.3.1 (2014-09-12)

- Replaced `Stoplight::Failure#error` with `#error_class` and `#error_message`.
  Also changed the constructor to take the class and the message instead of the
  error.

## v0.3.0 (2014-09-11)

- Allowed formatting notifications.
- Added automatic recovery from red lights.
- Added `Stoplight::DataStore#clear_stale` for clearing stale lights.
- Removed forwarded methods on `Stoplight` module.
- Moved some methods from `Stoplight::DataStore::Base` to
  `Stoplight::DataStore`.
- Renamed `Stoplight::DataStore::Base#purge` to `#clear_stale`.
- Renamed `Stoplight::DataStore::Base#delete` to `#clear`.
- Prefixed data store getters with `get_`.
- Added `Stoplight::DataStore::Base#sync`.
- Changed `Stoplight::DataStore::Base#get_failures` to return actual failures
  (`Stoplight::Failure`) instead of strings.

## v0.2.1 (2014-08-20)

- Forced times to be serialized as strings.

## v0.2.0 (2014-08-18)

- Switched `Stoplight.data_store` and `Stoplight.notifiers` over to using
  simple accessors.
- Modified `Stoplight::DataStore::Redis` to accept an instance of `Redis`.
- Refactored `Stoplight::DataStore::Redis` to use fewer keys.
- Created `Stoplight::Notifier` and subclasses.
- Sent notifications when moving from green to red.
- Renamed `Stoplight::Light::DEFAULT_THRESHOLD` to
  `Stoplight::DEFAULT_THRESHOLD`.
- Renamed `Stoplight::Error::NoFallback` to `Stoplight::Error::RedLight`.
- Created `Stoplight::Mixin#stoplight` for easily creating and running simple
  stoplights.

## v0.1.0 (2014-08-12)

- Initial release.

[1]: http://semver.org/spec/v2.0.0.html
