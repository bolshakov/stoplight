local meta_key = KEYS[1]
local current_ts = tonumber(ARGV[1])

--  1 if the field is a new field in the hash and the value was set
local became_green = redis.call('HSETNX', meta_key, 'recovered_at', current_ts)

if became_green == 1 then
  redis.call("HDEL", meta_key, 'recovery_started_at', 'recovery_scheduled_after', 'breached_at')
end
return became_green
