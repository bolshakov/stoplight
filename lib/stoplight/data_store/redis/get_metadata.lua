local window_start_ts = tonumber(ARGV[1])
local recovery_window_start_ts = tonumber(ARGV[2])

local metadata_key = KEYS[1]
local recovery_probe_buckets_in_use_key = KEYS[2]
local sliding_window_buckets_key = KEYS[3]
local buckets_in_use_key = KEYS[4]
local is_window_enabled = buckets_in_use_key ~= nil

-- Splits a string by a given delimiter
-- @param str The string to split
-- @param delimiter The delimiter to split by
-- @return A table containing the split parts
-- @usage
--   local parts = split("a,b,c", ",") -- parts = {"a", "b", "c"}
local function split(str, delimiter)
    local result = {}
    for match in (str .. delimiter):gmatch("(.-)" .. delimiter) do
        table.insert(result, match)
    end
    return result
end

local function expire_buckets(buckets_key, start_at)
  local expired_buckets = redis.call('ZRANGE', buckets_key, '-inf', '(' .. start_at, "BYSCORE")

  if #expired_buckets > 0 then
    redis.call("ZREMRANGEBYSCORE", buckets_key, '-inf', '(' .. start_at)
  end

  return expired_buckets
end

local expired_recovery_buckets = expire_buckets(recovery_probe_buckets_in_use_key, recovery_window_start_ts)

local expired_buckets = {}

if is_window_enabled then
  local recovered_at = redis.call('HGET', metadata_key, 'recovered_at')
  if recovered_at then
    window_start_ts = math.max(window_start_ts, tonumber(recovered_at))
  end

  expired_buckets = expire_buckets(buckets_in_use_key, window_start_ts)
end

local buckets_expired = #expired_buckets + #expired_recovery_buckets

if buckets_expired > 0 then
  local deleted_sums = redis.call(
    'HGETDEL', sliding_window_buckets_key,
    "FIELDS", #expired_buckets + #expired_recovery_buckets,
    unpack(expired_buckets), unpack(expired_recovery_buckets)
  )

  local total_recovery_successes_removed = 0
  local total_recovery_failures_removed = 0
  local total_successes_removed = 0
  local total_failures_removed = 0

  for idx = 1, #expired_buckets do
    local parts = split(expired_buckets[idx], ":")

    if #parts == 2 then
      if parts[1] == "errors" then
        total_failures_removed = total_failures_removed + (deleted_sums[idx] or 0)
      elseif parts[1] == "successes" then
        total_successes_removed = total_successes_removed + (deleted_sums[idx] or 0)
      else
        error("Invalid bucket format in sliding window: " .. expired_buckets[idx])
      end
    else
      error("Invalid bucket format in sliding window: " .. expired_buckets[idx])
    end
  end

  for idx = 1, #expired_recovery_buckets do
    local parts = split(expired_recovery_buckets[idx], ":")

    if #parts == 2 then
      if parts[1] == "recovery_probe_errors" then
        total_recovery_failures_removed = total_recovery_failures_removed + (deleted_sums[idx + #expired_buckets] or 0)
      elseif parts[1] == "recovery_probe_successes" then
        total_recovery_successes_removed = total_recovery_successes_removed + (deleted_sums[idx + #expired_buckets] or 0)
      else
        error("Invalid bucket format in sliding window: " .. expired_recovery_buckets[idx])
      end
    else
      error("Invalid bucket format in sliding window: " .. expired_recovery_buckets[idx])
    end
  end

  if total_recovery_successes_removed > 0 then
    redis.call("HINCRBY", metadata_key, "recovery_probe_successes", -total_recovery_successes_removed)
  end

  if total_recovery_failures_removed > 0 then
    redis.call("HINCRBY", metadata_key, "recovery_probe_errors", -total_recovery_failures_removed)
  end

  if total_successes_removed > 0 then
    redis.call("HINCRBY", metadata_key, "successes", -total_successes_removed)
  end

  if total_failures_removed > 0 then
    redis.call("HINCRBY", metadata_key, "errors", -total_failures_removed)
  end
end

return redis.call('HGETALL',  metadata_key)
