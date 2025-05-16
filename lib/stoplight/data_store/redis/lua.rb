# frozen_string_literal: true

module Stoplight
  module DataStore
    class Redis
      # @api private
      module Lua
        RECORD_FAILURE = File.read(File.join(__dir__, "record_failure.lua"))
        RECORD_SUCCESS = File.read(File.join(__dir__, "record_success.lua"))
        GET_METADATA = File.read(File.join(__dir__, "get_metadata.lua"))

        TRANSITION_TO_YELLOW = <<~LUA
          local meta_key = KEYS[1]
          local current_ts = tonumber(ARGV[1])

          -- HSETNX returns 1 if field is new and was set, 0 if field already exists
          local became_yellow = redis.call('HSETNX', meta_key, 'recovery_started_at', current_ts)
          if became_yellow == 1 then
            redis.call('HDEL', meta_key, 'recovery_scheduled_after', 'last_breach_at')
          end
          return became_yellow
        LUA

        TRANSITION_TO_RED = <<~LUA
          local meta_key = KEYS[1]
          local current_ts = tonumber(ARGV[1])
          local recovery_scheduled_after_ts = tonumber(ARGV[2])

          --  1 if the field is a new field in the hash and the value was set
          local became_red = redis.call('HSETNX', meta_key, 'last_breach_at', current_ts)
          if became_red == 1 then
            redis.call('HSET', meta_key, 'recovery_scheduled_after', recovery_scheduled_after_ts, 'last_breach_at', current_ts)
          else
            redis.call('HSET', meta_key, 'recovery_scheduled_after', recovery_scheduled_after_ts)
          end
          redis.call("HDEL", meta_key, "recovery_started_at")
          return became_red
        LUA
      end
    end
  end
end
