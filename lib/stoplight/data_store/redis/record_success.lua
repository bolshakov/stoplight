local metric_name = ARGV[1]
local request_ts = tonumber(ARGV[2])
local bucket = tonumber(ARGV[3])
local metadata_ttl = tonumber(ARGV[4])

local metadata_key = KEYS[1]
local buckets_in_use_key = KEYS[2]
local sliding_window_key = KEYS[3]
local is_window_enabled = sliding_window_key ~= nil and buckets_in_use_key ~= nil

-- Record success
if is_window_enabled then
  local bucket_sum = redis.call('HINCRBY', sliding_window_key, bucket, 1)
  local is_new_bucket = bucket_sum == 1

  if is_new_bucket then
    redis.call('ZADD', buckets_in_use_key, bucket, bucket)
  end

  -- Sure we need this?
  --redis.call('EXPIRE', sliding_window_key, metadata_ttl)
  --redis.call('EXPIRE', buckets_in_use_key, metadata_ttl)
end

-- Update metadata
local meta = redis.call('HMGET', metadata_key, 'last_success_at', 'consecutive_successes', metric_name)
local prev_success_ts = tonumber(meta[1])
local prev_consecutive_successes = tonumber(meta[2]) or 0

local common_meta = {
  'consecutive_errors', 0,
  'consecutive_successes', prev_consecutive_successes + 1
}

if is_window_enabled then
  local prev_metric = tonumber(meta[3]) or 0
  common_meta[#common_meta + 1] = metric_name
  common_meta[#common_meta + 1] = prev_metric + 1
end

if not prev_success_ts or request_ts > prev_success_ts then
  redis.call('HSET', metadata_key, 'last_success_at', request_ts, unpack(common_meta))
else
  redis.call('HSET', metadata_key, unpack(common_meta))
end

redis.call('EXPIRE', metadata_key, metadata_ttl) -- Not supported in Redis 6.2:, 'GT')
