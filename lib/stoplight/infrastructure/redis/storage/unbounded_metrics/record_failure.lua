local failure_ts = tonumber(ARGV[1])
local failure_json = ARGV[2]
local metrics_ttl = tonumber(ARGV[3])

local metrics_key = KEYS[1]

-- Update metadata
local meta = redis.call('HMGET', metrics_key, 'last_error_at', 'consecutive_errors')
local prev_failure_ts = tonumber(meta[1])
local prev_consecutive_errors = tonumber(meta[2])

redis.call('EXPIRE', metrics_key, metrics_ttl)

local consecutive_errors = (prev_consecutive_errors or 0) + 1
local consecutive_successes = 0

if not prev_failure_ts or failure_ts > prev_failure_ts then
  redis.call(
    'HSET', metrics_key,
    'last_error_at', failure_ts,
    'last_error_json', failure_json,
    'consecutive_errors', consecutive_errors,
    'consecutive_successes', consecutive_successes
  )

  local last_success_at = redis.call("HGET", metrics_key, "last_success_at")
  return {last_success_at, failure_json, consecutive_errors, consecutive_successes}
else
  redis.call(
    'HSET', metrics_key,
    'consecutive_errors', consecutive_errors,
    'consecutive_successes', consecutive_successes
  )

  local meta = redis.call("HMGET", metrics_key, "last_success_at", "last_error_json")
  return {meta[1], meta[2], consecutive_errors, consecutive_successes}
end
