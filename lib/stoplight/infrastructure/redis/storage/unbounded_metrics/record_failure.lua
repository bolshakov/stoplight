-- @include now

local metrics_key = KEYS[1]
local error_json = ARGV[1]
local metrics_ttl = tonumber(ARGV[2])

-- Update metadata
local meta = redis.call('HMGET', metrics_key, 'consecutive_errors', "last_success_at")
local prev_consecutive_errors = tonumber(meta[1])
local last_success_at = meta[2]
local failure_ts = now() / 1000.0

local consecutive_errors = (prev_consecutive_errors or 0) + 1
local consecutive_successes = 0

-- Always update with current timestamp (out-of-order impossible with Redis time)
redis.call(
  'HSET', metrics_key,
  'last_error_at', failure_ts,
  'last_error_json', error_json,
  'consecutive_errors', consecutive_errors,
  'consecutive_successes', consecutive_successes
)

redis.call('EXPIRE', metrics_key, metrics_ttl)

return {last_success_at, error_json, consecutive_errors, consecutive_successes}
