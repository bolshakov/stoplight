local metric_name = ARGV[1]
local failure_ts = tonumber(ARGV[2])
local bucket = tonumber(ARGV[3])
local failure_json = ARGV[4]
local metadata_ttl = tonumber(ARGV[5])

local metadata_key = KEYS[1]
local buckets_in_use_key = KEYS[2]
local sliding_window_key = KEYS[3]
local is_window_enabled = sliding_window_key ~= nil and buckets_in_use_key ~= nil

-- Record failure
if is_window_enabled then
  local bucket_sum = redis.call('HINCRBY', sliding_window_key, bucket, 1)
  local is_new_bucket = bucket_sum == 1

  if is_new_bucket then
    redis.call('ZADD', buckets_in_use_key, bucket, bucket)
  end

  -- Sure we need this?
  redis.call('EXPIRE', sliding_window_key, metadata_ttl)
  redis.call('EXPIRE', buckets_in_use_key, metadata_ttl)
end

-- Update metadata
local meta = redis.call('HMGET', metadata_key, 'last_error_at', 'consecutive_errors', metric_name)
local prev_failure_ts = tonumber(meta[1])

local prev_consecutive_errors = tonumber(meta[2]) or 0

local common_meta = {
  'consecutive_successes', 0,
  'consecutive_errors', prev_consecutive_errors + 1
}

if is_window_enabled then
    local prev_metric = tonumber(meta[3]) or 0
    common_meta[#common_meta + 1] = metric_name
    common_meta[#common_meta + 1] = prev_metric + 1
end

if not prev_failure_ts or failure_ts > prev_failure_ts then
  redis.call(
    'HSET', metadata_key,
    'last_error_at', failure_ts,
    'last_error_json', failure_json,
    unpack(common_meta)
  )
else
  redis.call('HSET', metadata_key, unpack(common_meta))
end

redis.call('EXPIRE', metadata_key, metadata_ttl) -- Not supported in Redis 6.2:, 'GT')
