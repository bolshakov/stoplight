local request_ts = tonumber(ARGV[1])
local request_id = ARGV[2]
local bucket_ttl = tonumber(ARGV[3])
local metadata_ttl = tonumber(ARGV[4])

local metrics_key = KEYS[1]
local successes_key = KEYS[2]

-- Record success
if successes_key ~= nil then
  redis.call('ZADD', successes_key, request_ts, request_id)
  redis.call('EXPIRE', successes_key, bucket_ttl) -- Not supported in Redis 6.2:, 'NX')
end

-- Update metadata
local meta = redis.call('HMGET', metrics_key, 'last_success_at', 'consecutive_successes')
local prev_success_ts = tonumber(meta[1])
local prev_consecutive_successes = tonumber(meta[2])

local consecutive_errors = 0
local consecutive_successes = (prev_consecutive_successes or 0) + 1

redis.call('EXPIRE', metrics_key, metadata_ttl) -- Not supported in Redis 6.2:, 'GT')

if not prev_success_ts or request_ts > prev_success_ts then
  redis.call(
    'HSET', metrics_key,
    'last_success_at', request_ts,
    'consecutive_errors', consecutive_errors,
    'consecutive_successes', consecutive_successes
  )
else
  redis.call(
    'HSET', metrics_key,
    'consecutive_errors', consecutive_errors,
    'consecutive_successes', consecutive_successes
  )
end

-- @include window_metrics/_metrics_snapshot

local number_of_metric_buckets = tonumber(ARGV[5])
local window_start_ts = tonumber(ARGV[6])
local window_end_ts = tonumber(ARGV[7])
local metrics_fields = {}
for idx = 8, #ARGV do
  table.insert(metrics_fields, ARGV[idx])
end

local success_keys, failure_keys = slice_window_keys(KEYS, 2, number_of_metric_buckets)

return build_metrics_snapshot(metrics_key, success_keys, failure_keys, window_start_ts, window_end_ts, metrics_fields)
