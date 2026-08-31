-- Subtracts each evicted bucket's counts from the running totals before deleting it, so
-- total_successes/total_failures stay exact. Window is the half-open interval
-- (bucket_ts - window_size, bucket_ts] - events at or before window_start are excluded.
--
-- O(K), K = buckets that had writes and are now stale. K <= window_size in steady state,
-- but a long idle gap can dump the whole backlog into one call on the next write.
--
-- HMGET/HDEL splat fields through unpack(), capped at 8000 args - verified across every
-- Redis/Valkey version this gem supports - so eviction runs in fixed-size batches.
-- ZRANGE/ZREMRANGEBYSCORE aren't variadic and skip that limit; keeping both in the same
-- atomic script call as the batched loop means ZREMRANGEBYSCORE always deletes exactly
-- what ZRANGE read.
local EVICT_BATCH_SIZE = 1000

local function evict_buckets(metrics_key, ts_index_key, window_start)
  local buckets = redis.call('ZRANGE', ts_index_key, '-inf', window_start, 'BYSCORE')
  if #buckets == 0 then
    return
  end

  for from = 1, #buckets, EVICT_BATCH_SIZE do
    local to = math.min(from + EVICT_BATCH_SIZE - 1, #buckets)

    local fields = {}
    for i = from, to do
      fields[#fields + 1] = buckets[i] .. ':f'
      fields[#fields + 1] = buckets[i] .. ':s'
    end

    local values = redis.call('HMGET', metrics_key, unpack(fields))

    local failures, successes = 0, 0
    for i = 1, #values, 2 do
      failures = failures + (tonumber(values[i]) or 0)
      successes = successes + (tonumber(values[i + 1]) or 0)
    end

    redis.call('HINCRBY', metrics_key, 'total_failures', -failures)
    redis.call('HINCRBY', metrics_key, 'total_successes', -successes)
    redis.call('HDEL', metrics_key, unpack(fields))
  end

  redis.call('ZREMRANGEBYSCORE', ts_index_key, '-inf', window_start)
end
