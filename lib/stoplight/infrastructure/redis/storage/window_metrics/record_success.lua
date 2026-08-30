-- @include window_metrics/_evict

local request_ts   = tonumber(ARGV[1])         -- float, used for metadata timestamps
local window_size  = tonumber(ARGV[2])
local metadata_ttl = tonumber(ARGV[3])

local key       = KEYS[1]
local idx       = KEYS[2]
local bucket_ts = math.floor(request_ts)       -- integer second, used for bucket keys

evict_buckets(key, idx, bucket_ts - window_size)

local bucket = 'bucket:' .. bucket_ts
redis.call('HINCRBY', key, bucket .. ':s', 1)     -- increment second's bucket
redis.call('HINCRBY', key, 'total_successes', 1)  -- increment running sum
redis.call('ZADD', idx, bucket_ts, bucket)        -- index bucket used bucket name

local prev_success_ts = tonumber(redis.call('HGET', key, 'last_success_at'))
redis.call('HINCRBY', key, 'consecutive_successes', 1)

if not prev_success_ts or request_ts > prev_success_ts then
  redis.call('HSET', key, 'last_success_at', request_ts, 'consecutive_errors', 0)
else
  redis.call('HSET', key, 'consecutive_errors', 0)
end

redis.call('EXPIRE', key, metadata_ttl)
redis.call('EXPIRE', idx, metadata_ttl)
