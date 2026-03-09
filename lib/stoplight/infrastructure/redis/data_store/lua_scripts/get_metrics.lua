local number_of_metric_buckets = tonumber(ARGV[1])
local window_start_ts = tonumber(ARGV[2])
local window_end_ts = tonumber(ARGV[3])
local metrics_keys = {}
for idx = 4, #ARGV do
  table.insert(metrics_keys, ARGV[idx])
end

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

offset = offset + number_of_metric_buckets
local errors = count_events(offset, number_of_metric_buckets, window_start_ts)

local metrics = redis.call('HMGET',  metadata_key, unpack(metrics_keys))
return {successes, errors, unpack(metrics)}
