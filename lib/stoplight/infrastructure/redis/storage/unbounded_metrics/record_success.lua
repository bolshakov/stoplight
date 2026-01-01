local request_ts = tonumber(ARGV[1])
local metrics_ttl = tonumber(ARGV[2])

local metrics_key = KEYS[1]

-- Update metadata
local meta = redis.call('HMGET', metrics_key, 'last_success_at', 'consecutive_successes')
local prev_success_ts = tonumber(meta[1])
local prev_consecutive_successes = tonumber(meta[2])

if not prev_success_ts or request_ts > prev_success_ts then
  redis.call(
    'HSET', metrics_key,
    'last_success_at', request_ts,
    'consecutive_errors', 0,
    'consecutive_successes', (prev_consecutive_successes or 0) + 1
  )
else
  redis.call(
    'HSET', metrics_key,
    'consecutive_errors', 0,
    'consecutive_successes', (prev_consecutive_successes or 0) + 1
  )
end

redis.call('EXPIRE', metrics_key, metrics_ttl)
