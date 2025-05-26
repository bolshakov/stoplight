local request_ts = tonumber(ARGV[1])
local request_id = ARGV[2]
local bucket_ttl = tonumber(ARGV[3])
local metadata_ttl = tonumber(ARGV[4])

local metadata_key = KEYS[1]
local successes_key = KEYS[2]

-- Record success
if successes_key ~= nil then
  redis.call('ZADD', successes_key, request_ts, request_id)
  redis.call('EXPIRE', successes_key, bucket_ttl) -- Not supported in Redis 6.2:, 'NX')
end

-- Update metadata
local meta = redis.call('HMGET', metadata_key, 'last_success_at', 'consecutive_successes')
local prev_success_ts = tonumber(meta[1])
local prev_consecutive_successes = tonumber(meta[2])

if not prev_success_ts or request_ts > prev_success_ts then
  redis.call(
    'HSET', metadata_key,
    'last_success_at', request_ts,
    'consecutive_failures', 0,
    'consecutive_successes', (prev_consecutive_successes or 0) + 1
  )
else
  redis.call(
    'HSET', metadata_key,
    'consecutive_failures', 0,
    'consecutive_successes', (prev_consecutive_successes or 0) + 1
  )
end

redis.call('EXPIRE', metadata_key, metadata_ttl) -- Not supported in Redis 6.2:, 'GT')
