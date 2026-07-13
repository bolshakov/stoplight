local request_ts = tonumber(ARGV[1])
local metrics_ttl = tonumber(ARGV[2])

local metrics_key = KEYS[1]

-- Update metadata
local meta = redis.call('HMGET', metrics_key, 'last_success_at', 'consecutive_successes')
local prev_success_ts = tonumber(meta[1])
local prev_consecutive_successes = tonumber(meta[2])

local consecutive_errors = 0
local consecutive_successes = (prev_consecutive_successes or 0) + 1

redis.call('EXPIRE', metrics_key, metrics_ttl)

if not prev_success_ts or request_ts > prev_success_ts then
  redis.call(
    'HSET', metrics_key,
    'last_success_at', request_ts,
    'consecutive_errors', consecutive_errors,
    'consecutive_successes', consecutive_successes
  )

  local meta = redis.call("HMGET", metrics_key, "last_success_at", "last_error_json")
  return {meta[1], meta[2], consecutive_errors, consecutive_successes}
else
  redis.call(
    'HSET', metrics_key,
    'consecutive_errors', consecutive_errors,
    'consecutive_successes', consecutive_successes
  )

  local last_error_json = redis.call("HGET", metrics_key, "last_error_json")
  return {prev_success_ts, last_error_json, consecutive_errors, consecutive_successes}
end
