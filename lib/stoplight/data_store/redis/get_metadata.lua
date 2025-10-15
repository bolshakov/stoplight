local window_start_ts = tonumber(ARGV[1])
local recovery_window_start_ts = tonumber(ARGV[2])
local window_enabled = tonumber(ARGV[3]) == 1

local metadata_key = KEYS[1]
local recovery_probe_buckets_in_use_key = KEYS[2]
local recovery_probe_error_sliding_window_key = KEYS[3]
local recovery_probe_success_sliding_window_key = KEYS[4]
local buckets_in_use_key = KEYS[5]
local error_sliding_window_key = KEYS[6]
local success_sliding_window_key = KEYS[7]

-- Slide the window by removing expired buckets and substracting their sums from the running sum
local function substract_buckets(sliding_window_key, metric_name, expired_buckets)
    local deleted_sums = redis.call('HGETDEL', sliding_window_key, "FIELDS", #expired_buckets, unpack(expired_buckets))
    local total_removed = 0
    for idx = 1, #deleted_sums do
        total_removed = total_removed + (deleted_sums[idx] or 0)
    end

    redis.call("HINCRBY", metadata_key, metric_name, -total_removed)
end

local function slide_window(buckets_key, start_at, metrics)
  local expired_buckets = redis.call('ZRANGEBYSCORE', buckets_key, '-inf', '(' .. start_at)

  if #expired_buckets > 0 then
    redis.call("ZREMRANGEBYSCORE", buckets_key, '-inf', '(' .. start_at)

    for sliding_window_key, metric_name in pairs(metrics) do
        substract_buckets(sliding_window_key, metric_name, expired_buckets)
    end
  end
end

slide_window(recovery_probe_buckets_in_use_key, recovery_window_start_ts, {
    [recovery_probe_error_sliding_window_key] = "recovery_probe_errors",
    [recovery_probe_success_sliding_window_key] = "recovery_probe_successes",
})

if window_enabled then
  -- It possible that after a successful recovery, Stoplight still see metrics
  -- that are older than the recovery window. To prevent this from happening,
  -- we need to limit the start time of the window to the time of the last recovery.
  -- TODO: Needs testing, I don't think we have this behaviour for Memory data store
  local recovered_at = redis.call('HGET', metadata_key, 'recovered_at')
  if recovered_at then
      window_start_ts = math.max(window_start_ts, tonumber(recovered_at))
  end

  slide_window(buckets_in_use_key, window_start_ts, {
      [error_sliding_window_key] = "errors",
      [success_sliding_window_key] = "successes",
  })
end

return redis.call('HGETALL',  metadata_key)
