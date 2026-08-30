-- Subtract buckets-bucket counts from the running totals before deleting them,
-- so total_successes/total_failures stay exact. The window covers the half-open interval
-- (bucket_ts - window_size, bucket_ts]: events at or before window_start are outside it.
--
-- Complexity: O(K) where K is the number of seconds that had writes and are now buckets.
-- K <= window_size in steady state, but after a long idle period the first write evicts
-- up to window_size entries in one call. This is acceptable because window_size is small
-- (300 by default) and the work is bounded regardless of event rate.
local function evict_buckets(key, idx, window_start)
  local buckets = redis.call('ZRANGE', idx, '-inf', window_start, 'BYSCORE')
  if #buckets == 0 then
    return
  end

  local fields = {}
  for _, bucket in ipairs(buckets) do
    fields[#fields + 1] = bucket .. ':f'
    fields[#fields + 1] = bucket .. ':s'
  end

  local values = redis.call('HMGET', key, unpack(fields))

  local failures, successes = 0, 0
  for i = 1, #values, 2 do
    failures = failures + (tonumber(values[i]) or 0)
    successes = successes + (tonumber(values[i + 1]) or 0)
  end

  redis.call('HINCRBY', key, 'total_failures', -failures)
  redis.call('HINCRBY', key, 'total_successes', -successes)

  redis.call('HDEL', key, unpack(fields))
  redis.call('ZREMRANGEBYSCORE', idx, '-inf', window_start)
end
