-- Returns current time in milliseconds since epoch.
-- In production: calls redis.call("TIME") for server time.
-- In tests: overridden with test double that reads from a Redis key.
local function now()
  local time = redis.call("TIME")
  local seconds = tonumber(time[1])
  local microseconds = tonumber(time[2])
  return seconds * 1000 + math.floor(microseconds / 1000)
end
