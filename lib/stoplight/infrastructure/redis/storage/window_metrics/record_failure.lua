local failure_ts = tonumber(ARGV[1])
local failure_id = ARGV[2]
local failure_json = ARGV[3]
local bucket_ttl = tonumber(ARGV[4])
local metadata_ttl = tonumber(ARGV[5])

local metrics_key = KEYS[1]
local failures_key = KEYS[2]

-- Record failure
if failures_key ~= nil then
  redis.call('ZADD', failures_key, failure_ts, failure_id)
  redis.call('EXPIRE', failures_key, bucket_ttl) -- Not supported in Redis 6.2:, 'NX')
end

-- Update metadata
local meta = redis.call('HMGET', metrics_key, 'last_error_at', 'consecutive_errors')
local prev_failure_ts = tonumber(meta[1])
local prev_consecutive_errors = tonumber(meta[2])

local consecutive_errors = (prev_consecutive_errors or 0) + 1
local consecutive_successes = 0
local last_error_json_result

if not prev_failure_ts or failure_ts > prev_failure_ts then
  redis.call(
    'HSET', metrics_key,
    'last_error_at', failure_ts,
    'last_error_json', failure_json,
    'consecutive_errors', consecutive_errors,
    'consecutive_successes', consecutive_successes
  )
  last_error_json_result = failure_json
else
  redis.call(
    'HSET', metrics_key,
    'consecutive_errors', consecutive_errors,
    'consecutive_successes', consecutive_successes
  )
  last_error_json_result = redis.call('HGET', metrics_key, 'last_error_json')
end
redis.call('EXPIRE', metrics_key, metadata_ttl) -- Not supported in Redis 6.2:, 'GT')

local last_success_at = redis.call('HGET', metrics_key, 'last_success_at')

-- @include window_metrics/_metrics_snapshot

local number_of_metric_buckets = tonumber(ARGV[6])
local window_start_ts = tonumber(ARGV[7])
local window_end_ts = tonumber(ARGV[8])

local success_keys, failure_keys = slice_window_keys(KEYS, 2, number_of_metric_buckets)
local successes = count_window_events(success_keys, window_start_ts, window_end_ts)
local errors = count_window_events(failure_keys, window_start_ts, window_end_ts)

return {successes, errors, last_success_at, last_error_json_result, consecutive_errors, consecutive_successes}
