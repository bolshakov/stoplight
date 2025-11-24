local token = ARGV[1]
local lock_key = KEYS[1]

if redis.call("get", lock_key) == token then
  return redis.call("del", lock_key)
end
