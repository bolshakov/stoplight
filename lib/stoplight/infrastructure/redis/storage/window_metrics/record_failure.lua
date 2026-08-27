local failure_ts_str = ARGV[1]
local failure_ts = tonumber(ARGV[1])
local failure_json = ARGV[2]
local zset_ttl = tonumber(ARGV[3])
local metadata_ttl = tonumber(ARGV[4])
-- window_start_ts passed as string from Ruby to avoid Lua float→string precision loss in ZCOUNT
local window_start_ts_str = ARGV[5]

local metrics_key = KEYS[1]
local failures_key = KEYS[2]
local successes_key = KEYS[3]

-- Unique member per event; two at the same timestamp would collapse in ZADD and
-- undercount in ZCOUNT. Shared with record_success, no separate key needed.
local failure_id = redis.call('HINCRBY', metrics_key, 'seq', 1)

-- Record failure and prune expired entries
redis.call('ZADD', failures_key, failure_ts, failure_id)
redis.call('ZREMRANGEBYSCORE', failures_key, '-inf', '(' .. window_start_ts_str)
redis.call('EXPIRE', failures_key, zset_ttl)

-- Update metadata
local meta = redis.call('HMGET', metrics_key, 'last_error_at')
local prev_failure_ts = tonumber(meta[1])

local last_error_json_result

local consecutive_errors = redis.call("HINCRBY", metrics_key, "consecutive_errors", 1)

if not prev_failure_ts or failure_ts > prev_failure_ts then
  redis.call(
    'HSET', metrics_key,
    'last_error_at', failure_ts,
    'last_error_json', failure_json,
    'consecutive_successes', 0
  )
  last_error_json_result = failure_json
else
  redis.call(
    'HSET', metrics_key,
    'consecutive_successes', 0
  )
  last_error_json_result = redis.call('HGET', metrics_key, 'last_error_json')
end

redis.call('EXPIRE', metrics_key, metadata_ttl)

local successes = tonumber(redis.call('ZCOUNT', successes_key, window_start_ts_str, failure_ts_str))
local errors = tonumber(redis.call('ZCOUNT', failures_key, window_start_ts_str, failure_ts_str))
local last_success_at = redis.call('HGET', metrics_key, 'last_success_at')

return {successes, errors, last_success_at, last_error_json_result, consecutive_errors, 0}
