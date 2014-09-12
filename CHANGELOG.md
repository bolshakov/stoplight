# Changelog

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
