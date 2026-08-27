-- window_start_ts_str and window_end_ts_str passed as strings from Ruby to avoid
-- Lua float→string precision loss in ZCOUNT
local window_start_ts_str = ARGV[1]
local window_end_ts_str = ARGV[2]
local metadata_fields = {}
for idx = 3, #ARGV do
  table.insert(metadata_fields, ARGV[idx])
end

local metrics_key = KEYS[1]
local successes_key = KEYS[2]
local failures_key = KEYS[3]

local successes = tonumber(redis.call('ZCOUNT', successes_key, window_start_ts_str, window_end_ts_str))
local errors = tonumber(redis.call('ZCOUNT', failures_key, window_start_ts_str, window_end_ts_str))
local metadata = redis.call('HMGET', metrics_key, unpack(metadata_fields))

return {successes, errors, unpack(metadata)}
