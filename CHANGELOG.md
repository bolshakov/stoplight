# Changelog

## v0.3.0 (2014-09-11)

- Allowed formatting notifications.
- Added automatic recovery from red lights.
- Added `Stoplight::DataStore#clear_stale` for clearing stale lights.

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
