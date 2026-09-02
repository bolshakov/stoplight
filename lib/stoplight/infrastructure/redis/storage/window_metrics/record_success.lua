-- @include now
-- @include window_metrics/_evict

local window_size  = tonumber(ARGV[1])
local metadata_ttl = tonumber(ARGV[2])

local metrics_key  = KEYS[1]
local ts_index_key = KEYS[2]
local request_ts   = now() / 1000.0
local bucket_ts    = math.floor(request_ts)

evict_buckets(metrics_key, ts_index_key, bucket_ts - window_size)

local bucket = 'bucket:' .. bucket_ts
redis.call('HINCRBY', metrics_key, bucket .. ':s', 1)
redis.call('HINCRBY', metrics_key, 'total_successes', 1)
redis.call('ZADD', ts_index_key, bucket_ts, bucket)

-- Always update with current timestamp (out-of-order impossible with Redis time)
redis.call(
  'HSET', metrics_key,
  'last_success_at', request_ts,
  'consecutive_errors', 0
)

redis.call('HINCRBY', metrics_key, 'consecutive_successes', 1)
redis.call('EXPIRE', metrics_key, metadata_ttl)
redis.call('EXPIRE', ts_index_key, metadata_ttl)
