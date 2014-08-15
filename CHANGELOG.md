# Changelog

- Switch `Stoplight.data_store` and `Stoplight.notifiers` over to using simple
  accessors.
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
