# frozen_string_literal: true

require "forwardable"

module Stoplight
  module DataStore
    # == Errors
    # All errors are stored in the sorted set where keys are serialized errors and
    # values (Redis uses "score" term) contain integer representations of the time
    # when an error happened.
    #
    # This data structure enables us to query errors that happened within a specific
    # period. We use this feature to support +window_size+ option.
    #
    # To avoid uncontrolled memory consumption, we keep at most +config.threshold+ number
    # of errors happened within last +config.window_size+ seconds (by default infinity).
    #
    # @see Base
    class Redis < Base
      extend Forwardable

      class << self
        # Generates a Redis key by joining the prefix with the provided pieces.
        #
        # @param pieces [Array<String, Integer>] Parts of the key to be joined.
        # @return [String] The generated Redis key.
        # @api private
        def key(*pieces)
          [KEY_PREFIX, *pieces].join(KEY_SEPARATOR)
        end

        BUCKET_SIZE = 600 # 10m

        # Retrieves the list of Redis bucket keys required to cover a specific time window.
        #
        # @param light_name [String] The name of the light (used as part of the Redis key).
        # @param metric [String] The metric type (e.g., "failures").
        # @param window_end [Time, Numeric] The end time of the window (can be a Time object or a numeric timestamp).
        # @param window_size [Numeric] The size of the time window in seconds.
        # @return [Array<String>] A list of Redis keys for the buckets that cover the time window.
        # @api private
        def buckets_for_window(light_name, metric:, window_end:, window_size:)
          window_end_ts = window_end.to_i
          window_start_ts = window_end_ts - [window_size, Base::METRICS_RETENTION_TIME].compact.min.to_i

          # Find bucket timestamps that contain any part of the window
          start_bucket = (window_start_ts / BUCKET_SIZE) * BUCKET_SIZE

          # End bucket is the last bucket that contains data within our window
          end_bucket = ((window_end_ts - 1) / BUCKET_SIZE) * BUCKET_SIZE

          (start_bucket..end_bucket).step(BUCKET_SIZE).map do |bucket_start|
            bucket_key(light_name, metric: metric, time: bucket_start)
          end
        end

        # Generates a Redis key for a specific metric and time.
        #
        # @param light_name [String] The name of the light.
        # @param metric [String] The metric type (e.g., "failures").
        # @param time [Time, Numeric] The time for which to generate the key.
        # @return [String] The generated Redis key.
        def bucket_key(light_name, metric:, time:)
          key("metrics", light_name, metric, (time.to_i / BUCKET_SIZE) * BUCKET_SIZE)
        end
      end

      KEY_SEPARATOR = ":"
      KEY_PREFIX = %w[stoplight v5].join(KEY_SEPARATOR)

      # This Lua script implements a notification deduplication mechanism:
      # 1. It checks if the current color transition (from_color → to_color) matches the previously recorded one
      # 2. If it's the same transition, returns 0 (don't notify) to prevent duplicate notifications
      # 3. If it's a different transition (or first time), it:
      #    - Records the new transition with a timestamp
      #    - Sets an expiration time on the record (allowing notifications to repeat after TTL as a fail-safe mechanism)
      #    - Returns 1 (proceed with notification)
      #
      # This ensures that when multiple servers detect the same transition simultaneously,
      # only one notification is sent, while still allowing future transitions to trigger notifications.
      #
      # This script is executed on redis and it's guaranteed that the operations are atomic.
      NOTIFICATION_DEDUPLICATION_SCRIPT = <<~LUA
        local last_notification_key = KEYS[1]

        local light_name = ARGV[1]
        local from_color = ARGV[2]
        local to_color = ARGV[3]
        local ttl = tonumber(ARGV[4])

        local prev_transition = redis.call('HMGET', last_notification_key, 'from_color', 'to_color')
        local prev_from_color, prev_to_color = unpack(prev_transition)

        if prev_from_color == from_color and prev_to_color == to_color then
          return 0
        else
          redis.call('HSET', last_notification_key, 'from_color', from_color, 'to_color', to_color)
          redis.call('EXPIRE', last_notification_key, ttl)
          return 1
        end
      LUA
      private_constant :NOTIFICATION_DEDUPLICATION_SCRIPT

      RECORD_FAILURE_SCRIPT = <<~LUA
        local failure_ts = tonumber(ARGV[1])
        local failure_id = ARGV[2]
        local failure_json = ARGV[3]
        local bucket_ttl = 86400

        local metadata_key = KEYS[1]
        local failures_key = KEYS[2]

        -- Record failure
        redis.call('ZADD', failures_key, failure_ts, failure_id)
        redis.call('EXPIRE', failures_key, bucket_ttl, "NX")
        
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
      LUA
      private_constant :RECORD_FAILURE_SCRIPT

      RECORD_SUCCESS_SCRIPT = <<~LUA
        local request_ts = tonumber(ARGV[1])
        local request_id = ARGV[2]
        local bucket_ttl = 86400

        local metadata_key = KEYS[1]
        local successes_key = KEYS[2]

        -- Record success
        redis.call('ZADD', successes_key, request_ts, request_id)
        redis.call('EXPIRE', successes_key, bucket_ttl, "NX")
        
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
      LUA
      private_constant :RECORD_SUCCESS_SCRIPT

      GET_METADATA_SCRIPT = <<~LUA
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
      private_constant :GET_METADATA_SCRIPT

      # @param redis [::Redis, ConnectionPool<::Redis>]
      def initialize(redis)
        @redis = redis
        @notification_deduplication_script_sha = @redis.then do |client|
          client.script("load", NOTIFICATION_DEDUPLICATION_SCRIPT)
        end
        @record_failure_script_sha = @redis.then do |client|
          client.script("load", RECORD_FAILURE_SCRIPT)
        end
        @record_success_script_sha = @redis.then do |client|
          client.script("load", RECORD_SUCCESS_SCRIPT)
        end
        @get_metadata_script_sha = @redis.then do |client|
          client.script("load", GET_METADATA_SCRIPT)
        end
      end

      def names
        pattern = key("metadata", "*")
        prefix_regex = /^#{key("metadata", "")}/
        @redis.then do |client|
          client.scan_each(match: pattern).to_a.map do |key|
            key.sub(prefix_regex, "")
          end
        end
      end

      def get_metadata(config)
        window_end = Time.now
        window_end_ts = window_end.to_i
        window_start_ts = window_end_ts - (config.window_size || [config.window_size, Base::METRICS_RETENTION_TIME].compact.min.to_i)
        recovery_window_start_ts = window_end_ts - config.cool_off_time.to_i

        failure_keys = failure_bucket_keys(config, window_end: window_end_ts)
        success_keys = success_bucket_keys(config, window_end: window_end_ts)
        recovery_probe_failure_keys = recovery_probe_failure_bucket_keys(config, window_end: window_end_ts)
        recovery_probe_success_keys = recovery_probe_success_bucket_keys(config, window_end: window_end_ts)

        successes, failures, recovery_probe_successes, recovery_probe_failures, meta = @redis.with do |client|
          client.evalsha(
            @get_metadata_script_sha,
            argv: [
              failure_keys.count,
              recovery_probe_failure_keys.count,
              window_start_ts,
              window_end_ts,
              recovery_window_start_ts
            ],
            keys: [
              metadata_key(config),
              *success_keys,
              *failure_keys,
              *recovery_probe_success_keys,
              *recovery_probe_failure_keys
            ]
          )
        end
        meta_hash = meta.each_slice(2).to_h.transform_keys(&:to_sym)
        last_failure_json = meta_hash.delete(:last_failure_json)
        last_failure = normalize_failure(last_failure_json, config.error_notifier) if last_failure_json

        Metadata.new(
          window_end:,
          window_size: config.window_size,
          successes: successes,
          failures: failures,
          recovery_probe_successes: recovery_probe_successes,
          recovery_probe_failures: recovery_probe_failures,
          last_failure:,
          **meta_hash
        )
      end

      # @param config [Stoplight::Light::Config] The light configuration.
      # @param failure [Stoplight::Failure] The failure to record.
      # @return [Stoplight::Metadata] The updated metadata after recording the failure.
      def record_failure(config, failure)
        current_ts = failure.time.to_i
        failure_json = failure.to_json

        @redis.then do |client|
          client.evalsha(
            @record_failure_script_sha,
            argv: [current_ts, SecureRandom.uuid, failure_json],
            keys: [
              metadata_key(config),
              failures_key(config, time: current_ts)
            ]
          )
        end
        get_metadata(config)
      end

      def record_success(config, request_id: SecureRandom.hex(12), request_time: Time.now)
        request_ts = request_time.to_i

        @redis.then do |client|
          client.evalsha(
            @record_success_script_sha,
            argv: [request_ts, request_id],
            keys: [
              metadata_key(config),
              successes_key(config, time: request_ts)
            ]
          )
        end
      end

      # Records a failed recovery probe for a specific light configuration.
      #
      # @param config [Stoplight::Light::Config] The light configuration.
      # @param failure [Failure] The failure to record.
      # @return [Stoplight::Metadata] The updated metadata after recording the failure.
      def record_recovery_probe_failure(config, failure)
        current_ts = failure.time.to_i
        failure_json = failure.to_json

        @redis.then do |client|
          client.evalsha(
            @record_failure_script_sha,
            argv: [current_ts, SecureRandom.uuid, failure_json],
            keys: [
              metadata_key(config),
              recovery_probe_failures_key(config, time: current_ts)
            ]
          )
        end
        get_metadata(config)
      end

      # Records a successful recovery probe for a specific light configuration.
      #
      # @param config [Stoplight::Light::Config] The light configuration.
      # @param request_id [String] The unique identifier for the request
      # @param request_time [Time] The time of the request
      # @return [Stoplight::Metadata] The updated metadata after recording the success.
      def record_recovery_probe_success(config, request_id: SecureRandom.hex(12), request_time: Time.now)
        request_ts = request_time.to_i

        @redis.then do |client|
          client.evalsha(
            @record_success_script_sha,
            argv: [request_ts, request_id],
            keys: [
              metadata_key(config),
              recovery_probe_successes_key(config, time: request_ts)
            ]
          )
        end
        get_metadata(config)
      end

      def get_state(config)
        @redis.then do |client|
          client.hget(metadata_key(config), "locked_state")
        end || State::UNLOCKED
      end

      def set_state(config, state)
        @redis.then do |client|
          client.hset(metadata_key(config), "locked_state", state)
        end
        state
      end

      def clear_state(config)
        key = metadata_key(config)
        state, _ = @redis.then do |client|
          client.multi do |transaction|
            transaction.hget(key, "locked_state")
            transaction.hdel(key, "locked_state")
          end
        end
        state || State::UNLOCKED
      end

      # Combined method that performs the state transition based on color
      #
      # @param config [Stoplight::Light::Config] The light configuration
      # @param color [String] The color to transition to ("GREEN", "YELLOW", or "RED")
      # @param current_time [Time] Current timestamp
      # @return [Boolean] true if this is the first instance to detect this transition
      def transition_to_color(config, color, current_time: Time.now)
        current_time.to_i

        case color
        when Color::GREEN
          transition_to_green(config)
        when Color::YELLOW
          transition_to_yellow(config, current_time:)
        when Color::RED
          transition_to_red(config, current_time:)
        else
          raise ArgumentError, "Invalid color: #{color}"
        end
      end

      # Transitions to GREEN state and ensures only one notification
      #
      # @param config [Stoplight::Light::Config] The light configuration
      # @return [Boolean] true if this is the first instance to detect this transition
      private def transition_to_green(config)
        meta_key = metadata_key(config)

        # Atomic operation using HDEL that returns number of fields actually deleted
        @redis.then do |client|
          client.hdel(meta_key, "recovery_started_at", "last_breach_at", "recovery_scheduled_after") > 0
        end
      end

      # Transitions to YELLOW (recovery) state and ensures only one notification
      #
      # @param config [Stoplight::Light::Config] The light configuration
      # @param current_time [Time] Current timestamp
      # @return [Boolean] true if this is the first instance to detect this transition
      private def transition_to_yellow(config, current_time: Time.now)
        current_ts = current_time.to_i
        meta_key = metadata_key(config)

        script = <<~LUA
          local meta_key = KEYS[1]
          local current_ts = tonumber(ARGV[1])
          local became_yellow = redis.call('HSETNX', meta_key, 'recovery_started_at', current_ts)
          if became_yellow == 1 then
            redis.call('HDEL', meta_key, 'recovery_scheduled_after', 'last_breach_at')
          end
          return became_yellow
        LUA

        # HSETNX returns 1 if field is new and was set, 0 if field already exists
        became_yellow = @redis.then do |client|
          client.eval(
            script,
            argv: [current_ts],
            keys: [meta_key]
          )
        end
        became_yellow == 1
      end

      # Transitions to RED state and ensures only one notification
      #
      # @param config [Stoplight::Light::Config] The light configuration
      # @param current_time [Time] Current timestamp
      # @return [Boolean] true if this is the first instance to detect this transition
      private def transition_to_red(config, current_time: Time.now)
        current_ts = current_time.to_i
        meta_key = metadata_key(config)
        recovery_scheduled_after_ts = current_ts + config.cool_off_time

        script = <<~LUA
          local meta_key = KEYS[1]
          local current_ts = tonumber(ARGV[1])
          local recovery_scheduled_after_ts = tonumber(ARGV[2])

          local became_red = redis.call('HSETNX', meta_key, 'last_breach_at', current_ts)
          if became_red == 1 then
            redis.call('HSET', meta_key, 'recovery_scheduled_after', recovery_scheduled_after_ts)
            redis.call("HDEL", meta_key, "recovery_started_at")
          end
          return became_red
        LUA

        became_red = @redis.then do |client|
          client.eval(
            script,
            argv: [current_ts, recovery_scheduled_after_ts],
            keys: [meta_key]
          )
        end

        became_red == 1
      end

      private def normalize_failure(failure, error_notifier)
        Failure.from_json(failure)
      rescue => e
        error_notifier.call(e)
        Failure.from_error(e)
      end

      def_delegator "self.class", :key

      private def failure_bucket_keys(config, window_end:)
        self.class.buckets_for_window(
          config.name,
          metric: "failure",
          window_end: window_end,
          window_size: config.window_size
        )
      end

      private def success_bucket_keys(config, window_end:)
        self.class.buckets_for_window(
          config.name,
          metric: "success",
          window_end: window_end,
          window_size: config.window_size
        )
      end

      private def recovery_probe_failure_bucket_keys(config, window_end:)
        self.class.buckets_for_window(
          config.name,
          metric: "recovery_probe_failure",
          window_end: window_end,
          window_size: config.cool_off_time
        )
      end

      private def recovery_probe_success_bucket_keys(config, window_end:)
        self.class.buckets_for_window(
          config.name,
          metric: "recovery_probe_success",
          window_end: window_end,
          window_size: config.cool_off_time
        )
      end

      private def successes_key(config, time:)
        self.class.bucket_key(config.name, metric: "success", time:)
      end

      private def failures_key(config, time:)
        self.class.bucket_key(config.name, metric: "failure", time:)
      end

      private def recovery_probe_successes_key(config, time:)
        self.class.bucket_key(config.name, metric: "recovery_probe_success", time:)
      end

      private def recovery_probe_failures_key(config, time:)
        self.class.bucket_key(config.name, metric: "recovery_probe_failure", time:)
      end

      private def metadata_key(config)
        key("metadata", config.name)
      end
    end
  end
end
