# frozen_string_literal: true

module Stoplight
  module DataStore
    class Redis
      # @api private
      module Lua
        RECORD_FAILURE = <<~LUA
          local failure_ts = tonumber(ARGV[1])
          local failure_id = ARGV[2]
          local failure_json = ARGV[3]
          local bucket_ttl = tonumber(ARGV[4])
          local metadata_ttl = tonumber(ARGV[5])
  
          local metadata_key = KEYS[1]
          local failures_key = KEYS[2]
  
          -- Record failure
          if failures_key ~= nil then
            redis.call('ZADD', failures_key, failure_ts, failure_id)
            redis.call('EXPIRE', failures_key, bucket_ttl, "NX")
          end
          
          -- Record metadata (last failure and consecutive failures)
          local meta = redis.call(
            'HMGET', metadata_key, 
            'last_failure_at', 'consecutive_failures'
          )
          local prev_failure_ts = tonumber(meta[1])
          local prev_consecutive_failures = tonumber(meta[2])
          
          -- Update failure metadata
          --   TODO: Maybe it worth resetting consecutive failures streak if prev_failure_ts happened long time ago
          --     e.g. local max_failure_age = math.max(window_size * 3, 3600)
          if not prev_failure_ts or failure_ts > prev_failure_ts then
            redis.call(
              'HSET', metadata_key, 
              'last_failure_at', failure_ts,
              'last_failure_json', failure_json,
              'consecutive_failures', (prev_consecutive_failures or 0) + 1,
              'consecutive_successes', 0
            )
          else
            redis.call(
              'HSET', metadata_key, 
              'consecutive_failures', (prev_consecutive_failures or 0) + 1,
              'consecutive_successes', 0
            )
          end
          redis.call('EXPIRE', metadata_key, metadata_ttl, "GT")
        LUA

        RECORD_SUCCESS = <<~LUA
          local request_ts = tonumber(ARGV[1])
          local request_id = ARGV[2]
          local bucket_ttl = tonumber(ARGV[3])
          local metadata_ttl = tonumber(ARGV[4])
  
          local metadata_key = KEYS[1]
          local successes_key = KEYS[2]
  
          -- Record success
          if successes_key ~= nil then
            redis.call('ZADD', successes_key, request_ts, request_id)
            redis.call('EXPIRE', successes_key, bucket_ttl, "NX")
          end
          
          -- Record metadata
          local meta = redis.call(
            'HMGET', metadata_key, 
            'last_success_at', 'consecutive_successes'
          )
          local prev_success_ts = tonumber(meta[1])
          local prev_consecutive_successes = tonumber(meta[2])
          
          -- Update metadata
          if not prev_success_ts or request_ts > prev_success_ts then
            redis.call(
              'HSET', metadata_key, 
              'last_success_at', request_ts,    
              'consecutive_failures', 0,
              'consecutive_successes', (prev_consecutive_successes or 0) + 1       
            )
          else
            redis.call(
              'HSET', metadata_key, 
              'consecutive_failures', 0,
              'consecutive_successes', (prev_consecutive_successes or 0) + 1
            )
          end
          redis.call('EXPIRE', metadata_key, metadata_ttl, "GT")
        LUA

        GET_METADATA = <<~LUA
          local number_of_metric_buckets = tonumber(ARGV[1])
          local number_of_recovery_buckets = tonumber(ARGV[2])
          local window_start_ts = tonumber(ARGV[3])
          local window_end_ts = tonumber(ARGV[4])
          local recovery_window_start_ts = tonumber(ARGV[5])
  
          local metadata_key = KEYS[1]
          
          -- Read number of successes within the time window
          local key_offset = 1 -- start from the second key (the first is metadata key)
          local successes = 0
          for idx = key_offset + 1, key_offset + number_of_metric_buckets do
            local key = KEYS[idx]
            successes = successes + tonumber(redis.call('ZCOUNT', key, window_start_ts, window_end_ts))
          end
       
          -- Read number of failures within the time window
          key_offset = key_offset + number_of_metric_buckets
          local failures = 0
          for idx = key_offset + 1, key_offset + number_of_metric_buckets do
            local key = KEYS[idx]
            failures = failures + tonumber(redis.call('ZCOUNT', key, window_start_ts, window_end_ts))
          end
  
          -- Read number of successful recovery probes within cooling off time
          key_offset = key_offset + number_of_metric_buckets 
          local recovery_probe_successes = 0
          for idx = key_offset + 1, key_offset + number_of_recovery_buckets do
            local key = KEYS[idx]
            recovery_probe_successes = recovery_probe_successes + tonumber(redis.call('ZCOUNT', key, recovery_window_start_ts, window_end_ts))
          end
  
          -- Read number of failed recovery probes within cooling off time
          key_offset = key_offset + number_of_recovery_buckets 
          local recovery_probe_failures = 0
          for idx = key_offset + 1, key_offset + number_of_recovery_buckets  do
            local key = KEYS[idx]
            recovery_probe_failures = recovery_probe_failures + tonumber(redis.call('ZCOUNT', key, recovery_window_start_ts, window_end_ts))
          end
  
          local metadata = redis.call('HGETALL',  metadata_key)
          return {successes, failures, recovery_probe_successes, recovery_probe_failures, metadata}
        LUA

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
