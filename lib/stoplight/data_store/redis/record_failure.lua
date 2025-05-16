local failure_ts = tonumber(ARGV[1])
local failure_id = ARGV[2]
local failure_json = ARGV[3]
local bucket_ttl = tonumber(ARGV[4])
local metadata_ttl = tonumber(ARGV[5])
local bucket = ARGV[6]

local metadata_key = KEYS[1]
local metrics_key = KEYS[2] -- A hash holding time buckets with counts
local buckets_key = KEYS[3] -- A sorted set holding buckets in use

if buckets_key then
  redis.call('HINCRBY', metrics_key, bucket, 1)
  redis.call('ZADD', buckets_key, failure_ts, bucket)
  redis.call('HEXPIRE', metrics_key, bucket_ttl, 'NX', 'FIELDS', 1, bucket)
  redis.call('EXPIRE', buckets_key, bucket_ttl, 'GT')
end

-- Record metadata (last failure and consecutive failures)
local meta = redis.call(
  'HMGET', metadata_key,
  'last_failure_at', 'consecutive_failures'
)
local prev_failure_ts = tonumber(meta[1])
local prev_consecutive_failures = tonumber(meta[2])

-- Update failure metadata
--   TODO: Maybe it worth resetting consecutive failures streak if prev_failure_ts happened long time ago
--     e.g. local max_failure_age = math.max(window_size * 3, 3600)
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
