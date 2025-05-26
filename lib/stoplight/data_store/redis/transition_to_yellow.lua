local meta_key = KEYS[1]
local current_ts = tonumber(ARGV[1])

-- HSETNX returns 1 if field is new and was set, 0 if field already exists
local became_yellow = redis.call('HSETNX', meta_key, 'recovery_started_at', current_ts)
if became_yellow == 1 then
  redis.call('HDEL', meta_key, 'recovery_scheduled_after', 'breached_at', 'recovered_at')
end
return became_yellow
