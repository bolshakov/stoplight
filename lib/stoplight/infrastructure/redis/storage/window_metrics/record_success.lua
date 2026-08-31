-- @include window_metrics/_evict

local request_ts   = tonumber(ARGV[1])         -- float, used for metadata timestamps
local window_size  = tonumber(ARGV[2])
local metadata_ttl = tonumber(ARGV[3])

local metrics_key  = KEYS[1]
local ts_index_key = KEYS[2]
local bucket_ts    = math.floor(request_ts) -- integer second, used for bucket keys

evict_buckets(metrics_key, ts_index_key, bucket_ts - window_size)

local bucket = 'bucket:' .. bucket_ts
redis.call('HINCRBY', metrics_key, bucket .. ':s', 1)     -- increment second's bucket
redis.call('HINCRBY', metrics_key, 'total_successes', 1)  -- increment running sum
redis.call('ZADD', ts_index_key, bucket_ts, bucket)       -- index bucket used bucket name

local prev_success_ts = tonumber(redis.call('HGET', metrics_key, 'last_success_at'))
redis.call('HINCRBY', metrics_key, 'consecutive_successes', 1)

if not prev_success_ts or request_ts > prev_success_ts then
  redis.call('HSET', metrics_key, 'last_success_at', request_ts, 'consecutive_errors', 0)
else
  redis.call('HSET', metrics_key, 'consecutive_errors', 0)
end

redis.call('EXPIRE', metrics_key, metadata_ttl)
redis.call('EXPIRE', ts_index_key, metadata_ttl)
