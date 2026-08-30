-- @include window_metrics/_evict

local current_ts  = tonumber(ARGV[1])
local window_size = tonumber(ARGV[2])

local key = KEYS[1]
local idx = KEYS[2]

evict_buckets(key, idx, math.floor(current_ts) - window_size)

-- copy arguments starting from index 3 to fields' tail
local fields = {'total_successes','total_failures', unpack(ARGV, 3) }
local metrics = redis.call('HMGET', key, unpack(fields))

metrics[1] = tonumber(metrics[1]) or 0 -- total_successes
metrics[2] = tonumber(metrics[2]) or 0 -- total_failures

return metrics
