-- Test stub for now() - checks Redis stack first (for tests), falls back to redis.call("TIME").
local function now()
  local test_time = redis.call("LINDEX", "stoplight:test_now_ms_stack", -1)
  if test_time then
    return tonumber(test_time)
  end
  local time = redis.call("TIME")
  local seconds = tonumber(time[1])
  local microseconds = tonumber(time[2])
  return seconds * 1000 + math.floor(microseconds / 1000)
end
