local buckets_count = tonumber(ARGV[1])
local recovery_buckets_count = tonumber(ARGV[2])

local metadata_key = KEYS[1]
local metrics_key = KEYS[2]

local buckets = {}
for idx = 1, buckets_count do
  table.insert(buckets, ARGV[2 + idx])
end
-- redis.log(redis.LOG_WARNING, "Reading metrics from " .. buckets_count .. " buckets=" .. cjson.encode(buckets))

local recovery_buckets = {}
for idx = 1, recovery_buckets_count do
  table.insert(recovery_buckets, ARGV[2 + buckets_count + idx])
end

-- redis.log(redis.LOG_WARNING, "Reading metrics from " .. recovery_buckets_count .. " recovery_buckets=" .. cjson.encode(recovery_buckets))

-- HMGET needs a single list of keys, so we need to combine failures and successes,
-- but in order: s:, f:, rs:, rf:
local prefixed_buckets = {}
for _, bucket in pairs(buckets) do
  table.insert(prefixed_buckets, "s:" .. bucket)
end
for _, bucket in pairs(buckets) do
  table.insert(prefixed_buckets, "f:" .. bucket)
end

for _, bucket in pairs(recovery_buckets) do
  table.insert(prefixed_buckets, "rs:" .. bucket)
end
for _, bucket in pairs(recovery_buckets) do
  table.insert(prefixed_buckets, "rf:" .. bucket)
end


-- redis.log(redis.LOG_WARNING, "Prefixed buckets=" .. cjson.encode(prefixed_buckets))


local successes = 0
local failures = 0
local recovery_successes = 0
local recovery_failures = 0

if #prefixed_buckets > 0 then
  local all_counts = redis.call('HMGET', metrics_key, unpack(prefixed_buckets))

  for idx = 1, #buckets do
    local count = tonumber(all_counts[idx])
    if count then
      successes = successes + count
    end
  end

  local offset = #buckets
  for idx = 1, #buckets do
    local count = tonumber(all_counts[offset + idx])
    if count then
      failures = failures + count
    end
  end

  local offset = offset + #buckets
  for idx = 1, #recovery_buckets do
    local count = tonumber(all_counts[offset + idx])
    if count then
      recovery_successes = recovery_successes + count
    end
  end

  local offset = offset + #recovery_buckets
  for idx = 1, #recovery_buckets do
    local count = tonumber(all_counts[offset + idx])
    if count then
      recovery_failures = recovery_failures + count
    end
  end
end

local metadata = redis.call('HGETALL',  metadata_key)
return {successes, failures, recovery_successes, recovery_failures, metadata}
