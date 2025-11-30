local failure_ts = tonumber(ARGV[1])
local failure_json = ARGV[2]
local metadata_ttl = tonumber(ARGV[3])

local metadata_key = KEYS[1]

-- Update metadata
local meta = redis.call('HMGET', metadata_key, 'last_error_at', 'consecutive_errors')
local prev_failure_ts = tonumber(meta[1])
local prev_consecutive_errors = tonumber(meta[2])

if not prev_failure_ts or failure_ts > prev_failure_ts then
  redis.call(
    'HSET', metadata_key,
    'last_error_at', failure_ts,
    'last_error_json', failure_json,
    'consecutive_errors', (prev_consecutive_errors or 0) + 1,
    'consecutive_successes', 0
  )
else
  redis.call(
    'HSET', metadata_key,
    'consecutive_errors', (prev_consecutive_errors or 0) + 1,
    'consecutive_successes', 0
  )
end

redis.call('EXPIRE', metadata_key, metadata_ttl)
