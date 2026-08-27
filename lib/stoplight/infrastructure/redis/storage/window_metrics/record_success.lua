local request_ts = tonumber(ARGV[1])
local request_id = ARGV[2]
local zset_ttl = tonumber(ARGV[3])
local metadata_ttl = tonumber(ARGV[4])
-- window_start_ts passed as string from Ruby to avoid Lua float→string precision loss
local window_start_ts_str = ARGV[5]

local metrics_key = KEYS[1]
local successes_key = KEYS[2]

-- Record success and prune expired entries
redis.call('ZADD', successes_key, request_ts, request_id)
redis.call('ZREMRANGEBYSCORE', successes_key, '-inf', '(' .. window_start_ts_str)
redis.call('EXPIRE', successes_key, zset_ttl)

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

redis.call('EXPIRE', metrics_key, metadata_ttl)
