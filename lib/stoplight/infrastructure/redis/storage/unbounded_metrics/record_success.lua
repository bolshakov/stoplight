-- @include now

local metrics_key = KEYS[1]
local metrics_ttl = tonumber(ARGV[1])

-- Update metadata
local prev_consecutive_successes = tonumber(redis.call('HGET', metrics_key, 'consecutive_successes'))
local request_ts = now() / 1000.0

-- Always update with current timestamp (out-of-order impossible with Redis time)
redis.call(
  'HSET', metrics_key,
  'last_success_at', request_ts,
  'consecutive_errors', 0,
  'consecutive_successes', (prev_consecutive_successes or 0) + 1
)

redis.call('EXPIRE', metrics_key, metrics_ttl)
