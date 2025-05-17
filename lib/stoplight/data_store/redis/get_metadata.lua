local window_end_ts = tonumber(ARGV[1])
local window_start_bucket = tonumber(ARGV[2])
local recovery_window_start_bucket = tonumber(ARGV[3])

local metadata_key = KEYS[1]
local metrics_key = KEYS[2]
local buckets_key = KEYS[3]
local recovery_buckets_key = KEYS[4]

local starts_with = function(str, prefix)
  return string.sub(str, 1, #prefix) == prefix
end

-- Read number of failures within the time window
local buckets = redis.call('ZRANGEBYSCORE', buckets_key, "(" .. window_start_bucket, window_end_ts)

-- The returned results are in arbitrary order, so we need to split them into failures and successes
local failures_buckets = {}
local successes_buckets = {}
if #buckets > 0 then
  for _, bucket in pairs(buckets) do
    if starts_with(bucket, "s:") then
      table.insert(successes_buckets, bucket)
    elseif starts_with(bucket, "f:") then
      table.insert(failures_buckets, bucket)
    else
      error("Unknown bucket type: " .. bucket)
    end
  end
end

-- HMGET needs a single list of keys, so we need to combine failures and successes,
-- but in order: first failures, then successes
local all_buckets = {}
for _, bucket in pairs(failures_buckets) do
  table.insert(all_buckets, bucket)
end
for _, bucket in pairs(successes_buckets) do
  table.insert(all_buckets, bucket)
end

local failures = 0
local successes = 0

if #all_buckets > 0 then
  local all_counts = redis.call('HMGET', metrics_key, unpack(all_buckets))

  for idx = 1, #failures_buckets do
    local count = all_counts[idx]
    failures = failures + count
  end

  local offset = #failures_buckets
  for idx = 1, #successes_buckets do
    local count = all_counts[offset + idx]
    successes = successes + count
  end
end

local recovery_buckets = redis.call('ZRANGEBYSCORE', recovery_buckets_key, "(" .. recovery_window_start_bucket, window_end_ts)

-- The returned results are in arbitrary order, so we need to split them into failures and successes
local recovery_probe_successes_buckets = {}
local recovery_probe_failures_buckets = {}
if #recovery_buckets > 0 then -- TODO: remove Iterator should handle this?
  for _, bucket in pairs(recovery_buckets) do
    if starts_with(bucket, "rs:") then
      table.insert(recovery_probe_successes_buckets, bucket)
    elseif starts_with(bucket, "rf:") then
      table.insert(recovery_probe_failures_buckets, bucket)
    else
      error("Unknown bucket type: " .. bucket)
    end
  end
end

-- HMGET needs a single list of keys, so we need to combine failures and successes,
-- but in order: first failures, then successes
local all_buckets = {}
for _, bucket in pairs(recovery_probe_failures_buckets) do
  table.insert(all_buckets, bucket)
end
for _, bucket in pairs(recovery_probe_successes_buckets) do
  table.insert(all_buckets, bucket)
end

local recovery_probe_failures = 0
local recovery_probe_successes = 0

if #all_buckets > 0 then
  local all_counts = redis.call('HMGET', metrics_key, unpack(all_buckets))

  for idx = 1, #recovery_probe_failures_buckets do
    local count = all_counts[idx]
    recovery_probe_failures = recovery_probe_failures + count
  end

  local offset = #recovery_probe_failures_buckets
  for idx = 1, #recovery_probe_successes_buckets do
    local count = all_counts[offset + idx]
    recovery_probe_successes = recovery_probe_successes + count
  end
end

local metadata = redis.call('HGETALL',  metadata_key)
return {successes, failures, recovery_probe_successes, recovery_probe_failures, metadata}
