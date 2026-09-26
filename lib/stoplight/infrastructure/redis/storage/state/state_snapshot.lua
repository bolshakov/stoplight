-- @include now

local meta_key = KEYS[1]

local state = redis.call('HMGET', meta_key, 'breached_at', 'locked_state', 'recovery_scheduled_after', 'recovery_started_at')
local current_time = now()
state[5] = current_time

return state
