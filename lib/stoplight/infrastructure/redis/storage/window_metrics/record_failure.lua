-- @include now
-- @include window_metrics/_evict

local failure_json = ARGV[1]
local window_size  = tonumber(ARGV[2])
local metadata_ttl = tonumber(ARGV[3])

local metrics_key  = KEYS[1]
local ts_index_key = KEYS[2]
local request_ts   = now() / 1000.0
local bucket_ts    = math.floor(request_ts)

evict_buckets(metrics_key, ts_index_key, bucket_ts - window_size)

local bucket = 'bucket:' .. bucket_ts
redis.call('HINCRBY', metrics_key, bucket .. ':f', 1)
redis.call('HINCRBY', metrics_key, 'total_failures', 1)
redis.call('ZADD', ts_index_key, bucket_ts, bucket)

local consecutive_errors = redis.call('HINCRBY', metrics_key, 'consecutive_errors', 1)

-- Always update with current timestamp (out-of-order impossible with Redis time)
redis.call(
  'HSET', metrics_key,
  'last_error_at', request_ts,
  'last_error_json', failure_json,
  'consecutive_successes', 0
)

redis.call('EXPIRE', metrics_key, metadata_ttl)
redis.call('EXPIRE', ts_index_key, metadata_ttl)

local result = redis.call('HMGET', metrics_key, 'last_success_at', 'total_successes', 'total_failures')
local last_success_at = result[1]
local total_successes = tonumber(result[2]) or 0
local total_failures = tonumber(result[3]) or 0

return {total_successes, total_failures, last_success_at, failure_json, consecutive_errors, 0}
