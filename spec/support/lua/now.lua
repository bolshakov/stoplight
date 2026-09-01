-- Test double for now(). Reads from a Redis stack that timecop extension controls.
-- Falls back to redis.call("TIME") if stack is empty (for backward compatibility).
local function now()
  local test_time = redis.call("LINDEX", "stoplight:test_now_ms_stack", -1)
  if test_time then
    return tonumber(test_time)
  end

  -- Fallback to actual time if stack is empty
  local time = redis.call("TIME")
  local seconds = tonumber(time[1])
  local microseconds = tonumber(time[2])
  return seconds * 1000 + math.floor(microseconds / 1000)
end
