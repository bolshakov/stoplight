local function slice_window_keys(keys, offset, number_of_metric_buckets)
  local success_keys, failure_keys = {}, {}
  for i = 1, number_of_metric_buckets do
    table.insert(success_keys, keys[offset + i])
  end
  for i = 1, number_of_metric_buckets do
    table.insert(failure_keys, keys[offset + number_of_metric_buckets + i])
  end
  return success_keys, failure_keys
end

local function count_window_events(keys, start_ts, end_ts)
  local total = 0
  for _, key in ipairs(keys) do
    total = total + tonumber(redis.call('ZCOUNT', key, start_ts, end_ts))
  end
  return total
end

local function build_metrics_snapshot(metrics_key, success_keys, failure_keys, window_start_ts, window_end_ts, metadata_fields)
  local successes = count_window_events(success_keys, window_start_ts, window_end_ts)
  local errors = count_window_events(failure_keys, window_start_ts, window_end_ts)
  local metadata = redis.call('HMGET', metrics_key, unpack(metadata_fields))

  return {successes, errors, unpack(metadata)}
end
