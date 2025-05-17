local number_of_metric_buckets = tonumber(ARGV[1])
local number_of_recovery_buckets = tonumber(ARGV[2])
local window_start_ts = tonumber(ARGV[3])
local window_end_ts = tonumber(ARGV[4])
local recovery_window_start_ts = tonumber(ARGV[5])

local metadata_key = KEYS[1]

local function count_events(start_idx, bucket_count, start_ts)
  local total = 0
  for idx = start_idx, start_idx + bucket_count - 1 do
    total = total + tonumber(redis.call('ZCOUNT', KEYS[idx], start_ts, window_end_ts))
  end
  return total
end

local offset = 2
local successes = count_events(2, number_of_metric_buckets, window_start_ts)

local offset = offset + number_of_metric_buckets
local failures = count_events(offset, number_of_metric_buckets, window_start_ts)

local offset = offset + number_of_metric_buckets
local recovery_probe_successes = count_events(offset, number_of_recovery_buckets, recovery_window_start_ts)

local offset = offset + number_of_recovery_buckets
local recovery_probe_failures = count_events(offset, number_of_recovery_buckets, recovery_window_start_ts)

local metadata = redis.call('HGETALL',  metadata_key)
return {successes, failures, recovery_probe_successes, recovery_probe_failures, metadata}
