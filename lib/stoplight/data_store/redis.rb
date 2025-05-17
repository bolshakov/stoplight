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

        BUCKETS = [1, 10, 60].freeze
        private_constant :BUCKETS
        def buckets
          BUCKETS
        end

        # Retrieves Redis keys for all bucket sizes at a specific time.
        #
        # @param time [Time, Numeric] The time for which to retrieve bucket keys.
        # @return [Array<String>] A list of Redis keys for the buckets.
        # @api private
        def buckets_for_time(time:)
          buckets.map do |bucket_size|
            bucket_key(time:, bucket_size:)
          end
        end

        # Retrieves the list of Redis bucket keys required to cover a specific time window.
        #
        # This method calculates which buckets (1-second, 10-second, or 60-second) are needed
        # to represent the data for a given time window. It selects the largest bucket size
        # that fits within the window and recursively includes smaller buckets for any remaining
        # time that does not align with the larger bucket boundaries.
        #
        # @param window_end [Time, Numeric] The end time of the window (can be a Time object or a numeric timestamp).
        # @param window_size [Numeric] The size of the time window in seconds.
        # @return [Array<String>] A list of Redis keys for the buckets that cover the time window.
        # @api private
        def buckets_for_window(window_end:, window_size:)
          # Determine the largest bucket size that fits within the window size.
          max_bucket_size = buckets.select { |size| size <= window_size }.max || buckets.first

          window_end_ts = window_end.to_i
          window_start_ts = window_end_ts - window_size.to_i + 1

          # Generate the bucket keys for the window using the largest bucket size
          # and recursively include smaller buckets for any remaining time.
          use_buckets_with_reminder(
            bucket_size: max_bucket_size,
            start_ts: window_start_ts,
            end_ts: window_end_ts
          )
        end

        # Recursively retrieves buckets for a given time range, including smaller buckets for reminders.
        #
        # @param bucket_size [Integer] The size of the bucket in seconds.
        # @param start_ts [Integer] The start timestamp of the range.
        # @param end_ts [Integer] The end timestamp of the range.
        # @return [Array<String>] A list of Redis keys for the buckets.
        private def use_buckets_with_reminder(bucket_size:, start_ts:, end_ts:)
          bucket_order = buckets.index(bucket_size)

          raise ArgumentError, "unsupported bucket size" unless bucket_order

          # Align to bucket_size-second boundaries
          aligned_start_ts = ((start_ts + bucket_size - 1) / bucket_size) * bucket_size  # Round up to next bucket_size boundary
          aligned_end_ts = (end_ts / bucket_size) * bucket_size # Round down to previous bucket_size boundary

          buckets = use_buckets(bucket_size:, start_ts: aligned_start_ts, end_ts: aligned_end_ts)

          if bucket_order == 0
            buckets
          else
            reminder_buckets = use_buckets_with_reminder(
              bucket_size: self.buckets.fetch(bucket_order - 1),
              start_ts: start_ts,
              end_ts: aligned_start_ts - 1
            )
            buckets + reminder_buckets
          end
        end

        # Generates Redis keys for buckets within a specific range.
        #
        # @param bucket_size [Integer] The size of the bucket in seconds.
        # @param start_ts [Integer] The start timestamp of the range.
        # @param end_ts [Integer] The end timestamp of the range.
        # @return [Array<String>] A list of Redis keys for the buckets.
        private def use_buckets(bucket_size:, start_ts:, end_ts:)
          start_ts.step(by: bucket_size, to: end_ts).map do |time|
            bucket_key(bucket_size:, time:)
          end
        end

        # Generates a Redis key for a specific bucket size and time.
        #
        # @param bucket_size [Integer] The size of the bucket in seconds.
        # @param time [Time, Numeric] The time for which to generate the key.
        # @return [String] The generated Redis key.
        private def bucket_key(bucket_size:, time:)
          ["#{bucket_size}s", (time.to_i / bucket_size) * bucket_size].join(KEY_SEPARATOR)
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

        buckets = if config.window_size
          window_size = config.window_size || [config.window_size, Base::METRICS_RETENTION_TIME].compact.min.to_i
          self.class.buckets_for_window(window_end: window_end_ts, window_size:)
        else
          []
        end

        recovery_buckets = self.class.buckets_for_window(window_end: window_end_ts, window_size: config.cool_off_time.to_i)

        successes, failures, recovery_probe_successes, recovery_probe_failures, meta = @redis.with do |client|
          client.evalsha(
            @get_metadata_sha,
            argv: [
              buckets.count,
              recovery_buckets.count,
              *buckets,
              *recovery_buckets
            ],
            keys: [
              metadata_key(config),
              metrics_key(config),
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

        buckets = if config.window_size
          buckets_with_prefix(self.class.buckets_for_time(time: current_ts), prefix: "f")
        else
          []
        end

        @redis.then do |client|
          client.evalsha(
            @record_failure_sha,
            argv: [
              current_ts,
              SecureRandom.uuid,
              failure_json,
              metrics_ttl,
              metadata_ttl,
              buckets.count,
              *buckets,
            ],
            keys: [
              metadata_key(config),
              metrics_key(config),
            ].compact
          )
        end
        get_metadata(config)
      end

      private def buckets_with_prefix(buckets, prefix:)
        buckets.map { |bucket| [prefix, bucket].join(KEY_SEPARATOR)}
      end

      def record_success(config, request_id: SecureRandom.hex(12), request_time: Time.now)
        request_ts = request_time.to_i

        buckets = if config.window_size
          buckets_with_prefix(self.class.buckets_for_time(time: request_ts), prefix: "s")
        else
          []
        end

        @redis.then do |client|
          client.evalsha(
            @record_success_sha,
            argv: [
              request_ts,
              request_id,
              metrics_ttl,
              metadata_ttl,
              buckets.count,
              *buckets,
            ],
            keys: [
              metadata_key(config),
              metrics_key(config),
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

        buckets = buckets_with_prefix(self.class.buckets_for_time(time: current_ts), prefix: "rf")

        @redis.then do |client|
          client.evalsha(
            @record_failure_sha,
            argv: [
              current_ts,
              SecureRandom.uuid,
              failure_json,
              metrics_ttl,
              metrics_ttl,
              buckets.count,
              *buckets
            ],
            keys: [
              metadata_key(config),
              metrics_key(config),
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

        buckets = buckets_with_prefix(self.class.buckets_for_time(time: request_ts), prefix: "rs")

        @redis.then do |client|
          client.evalsha(
            @record_success_sha,
            argv: [
              request_ts,
              request_id,
              metrics_ttl,
              metadata_ttl,
              buckets.count,
              *buckets
            ],
            keys: [
              metadata_key(config),
              metrics_key(config),
            ]
          )
        end
        get_metadata(config)
      end

      private def bucket(time, prefix: nil)
        [prefix, (time.to_i / bucket_size) * bucket_size].compact.join(KEY_SEPARATOR)
      end

      private def bucket_size
        5
      end

      private def metrics_key(config)
        key("metrics", config.name)
      end

      private def buckets_key(config)
        key("buckets", config.name)
      end

      private def recovery_buckets_key(config)
        key("recovery_buckets", config.name)
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

      private def metadata_key(config)
        key("metadata", config.name)
      end

      METRICS_TTL = 86400 # 1 day
      private_constant :METRICS_TTL

      private def metrics_ttl
        METRICS_TTL
      end

      METADATA_TTL =86400 * 7 # 7 days
      private_constant :METADATA_TTL

      private def metadata_ttl
        METADATA_TTL
      end
    end
  end
end
