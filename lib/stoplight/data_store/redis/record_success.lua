local request_ts = tonumber(ARGV[1])
local request_id = ARGV[2]
local bucket_ttl = tonumber(ARGV[3])
local metadata_ttl = tonumber(ARGV[4])
local buckets_count = tonumber(ARGV[5])

local metadata_key = KEYS[1]
local metrics_key = KEYS[2] -- A hash holding time buckets with counts

local buckets = {}
for idx = 1, buckets_count do
  table.insert(buckets, ARGV[5 + idx])
end

-- redis.log(redis.LOG_WARNING, "Writing metrics to buckets=" .. cjson.encode(buckets))

if #buckets > 0 then
  for _, bucket in pairs(buckets) do
    redis.call('HINCRBY', metrics_key, bucket, 1)
  end
  redis.call('HEXPIRE', metrics_key, bucket_ttl, 'NX', 'FIELDS', buckets_count, unpack(buckets))
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
