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
          start_bucket = (window_start_ts / bucket_size) * bucket_size

          # End bucket is the last bucket that contains data within our window
          end_bucket = ((window_end_ts - 1) / bucket_size) * bucket_size

          (start_bucket..end_bucket).step(bucket_size).map do |bucket_start|
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
          key("metrics", light_name, metric, (time.to_i / bucket_size) * bucket_size)
        end

        BUCKET_SIZE = 3600 # 1h
        private_constant :BUCKET_SIZE

        private def bucket_size
          BUCKET_SIZE
        end
      end

      KEY_SEPARATOR = ":"
      KEY_PREFIX = %w[stoplight v5].join(KEY_SEPARATOR)

      # @param redis [::Redis, ConnectionPool<::Redis>]
      def initialize(redis)
        @redis = redis
        @redis.then do |client|
          @record_failure_sha,
          @record_success_sha,
          @get_metadata_sha,
          @transition_to_yellow_sha,
          @transition_to_red_sha = client.pipelined do |pipeline|
            pipeline.script("load", Lua::RECORD_FAILURE)
            pipeline.script("load", Lua::RECORD_SUCCESS)
            pipeline.script("load", Lua::GET_METADATA)
            pipeline.script("load", Lua::TRANSITION_TO_YELLOW)
            pipeline.script("load", Lua::TRANSITION_TO_RED)
          end
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

        if config.window_size
          failure_keys = failure_bucket_keys(config, window_end: window_end_ts)
          success_keys = success_bucket_keys(config, window_end: window_end_ts)
        else
          failure_keys = []
          success_keys = []
        end
        recovery_probe_failure_keys = recovery_probe_failure_bucket_keys(config, window_end: window_end_ts)
        recovery_probe_success_keys = recovery_probe_success_bucket_keys(config, window_end: window_end_ts)

        successes, failures, recovery_probe_successes, recovery_probe_failures, meta = @redis.with do |client|
          client.evalsha(
            @get_metadata_sha,
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
            @record_failure_sha,
            argv: [current_ts, SecureRandom.uuid, failure_json],
            keys: [
              metadata_key(config),
              config.window_size && failures_key(config, time: current_ts)
            ].compact
          )
        end
        get_metadata(config)
      end

      def record_success(config, request_id: SecureRandom.hex(12), request_time: Time.now)
        request_ts = request_time.to_i

        @redis.then do |client|
          client.evalsha(
            @record_success_sha,
            argv: [request_ts, request_id],
            keys: [
              metadata_key(config),
              config.window_size && successes_key(config, time: request_ts)
            ].compact
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
            @record_failure_sha,
            argv: [current_ts, SecureRandom.uuid, failure_json],
            keys: [
              metadata_key(config),
              recovery_probe_failures_key(config, time: current_ts)
            ].compact
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
            @record_success_sha,
            argv: [request_ts, request_id],
            keys: [
              metadata_key(config),
              recovery_probe_successes_key(config, time: request_ts)
            ].compact
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

        became_yellow = @redis.then do |client|
          client.evalsha(
            @transition_to_yellow_sha,
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

        became_red = @redis.then do |client|
          client.evalsha(
            @transition_to_red_sha,
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
