local meta_key = KEYS[1]
local current_ts = tonumber(ARGV[1])
local recovery_scheduled_after_ts = tonumber(ARGV[2])

--  1 if the field is a new field in the hash and the value was set
local became_red = redis.call('HSETNX', meta_key, 'last_breach_at', current_ts)

if became_red == 1 then
  redis.call('HSET', meta_key, 'recovery_scheduled_after', recovery_scheduled_after_ts, 'last_breach_at', current_ts)
else
  -- Remove?
  redis.call('HSET', meta_key, 'recovery_scheduled_after', recovery_scheduled_after_ts)
end
redis.call("HDEL", meta_key, "recovery_started_at", "recovered_at")
return became_red
