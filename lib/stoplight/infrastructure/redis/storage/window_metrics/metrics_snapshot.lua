-- @include window_metrics/_metrics_snapshot

local number_of_metric_buckets = tonumber(ARGV[1])
local window_start_ts = tonumber(ARGV[2])
local window_end_ts = tonumber(ARGV[3])
local metrics_fields = {}
for idx = 4, #ARGV do
  table.insert(metrics_fields, ARGV[idx])
end

local metrics_key = KEYS[1]
local success_keys, failure_keys = slice_window_keys(KEYS, 1, number_of_metric_buckets)

return build_metrics_snapshot(metrics_key, success_keys, failure_keys, window_start_ts, window_end_ts, metrics_fields)
