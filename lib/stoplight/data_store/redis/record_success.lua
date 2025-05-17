local request_ts = tonumber(ARGV[1])
local request_id = ARGV[2]
local bucket_ttl = tonumber(ARGV[3])
local metadata_ttl = tonumber(ARGV[4])
local bucket = ARGV[5]

local metadata_key = KEYS[1]
local metrics_key = KEYS[2] -- A hash holding time buckets with counts
local buckets_key = KEYS[3] -- A sorted set holding buckets in use

-- Record success
if buckets_key then
  redis.call('HINCRBY', metrics_key, bucket, 1)
  --redis.log(redis.LOG_WARNING, 'Hash updated: key="' .. metrics_key .. '"  field="' .. bucket .. '" operation="INCRBY"')
  redis.call('ZADD', buckets_key, request_ts, bucket)
  --redis.log(redis.LOG_WARNING, 'Sorted Set element added key="' .. buckets_key .. '"  member="' .. bucket .. '" score="' .. request_ts .. '"')

  redis.call('HEXPIRE', metrics_key, bucket_ttl, 'NX', 'FIELDS', 1, bucket)
  redis.call('EXPIRE', buckets_key, bucket_ttl, 'GT')
end

-- Record metadata
local meta = redis.call(
  'HMGET', metadata_key,
  'last_success_at', 'consecutive_successes'
)
local prev_success_ts = tonumber(meta[1])
local prev_consecutive_successes = tonumber(meta[2])

-- Update metadata
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
redis.call('EXPIRE', metadata_key, metadata_ttl, "GT")
