local failure_ts = tonumber(ARGV[1])
local failure_id = ARGV[2]
local failure_json = ARGV[3]
local bucket_ttl = tonumber(ARGV[4])
local metadata_ttl = tonumber(ARGV[5])

local metadata_key = KEYS[1]
local failures_key = KEYS[2]

-- Record failure
if failures_key ~= nil then
  redis.call('ZADD', failures_key, failure_ts, failure_id)
  redis.call('EXPIRE', failures_key, bucket_ttl, "NX")
end

-- Record metadata
local meta = redis.call('HMGET', metadata_key, 'last_failure_at', 'consecutive_failures')
local prev_failure_ts = tonumber(meta[1])
local prev_consecutive_failures = tonumber(meta[2])

-- Update metadata
if not prev_failure_ts or failure_ts > prev_failure_ts then
  redis.call(
    'HSET', metadata_key,
    'last_failure_at', failure_ts,
    'last_failure_json', failure_json,
    'consecutive_failures', (prev_consecutive_failures or 0) + 1,
    'consecutive_successes', 0
  )
else
  redis.call(
    'HSET', metadata_key,
    'consecutive_failures', (prev_consecutive_failures or 0) + 1,
    'consecutive_successes', 0
  )
end
redis.call('EXPIRE', metadata_key, metadata_ttl, "GT")
