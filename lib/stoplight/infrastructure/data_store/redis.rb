# frozen_string_literal: true

require "forwardable"

module Stoplight
  module Infrastructure
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
      class Redis < Domain::DataStore
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
          # @param metric [String] The metric type (e.g., "errors").
          # @param window_end [Time, Numeric] The end time of the window (can be a Time object or a numeric timestamp).
          # @param window_size [Numeric] The size of the time window in seconds.
          # @return [Array<String>] A list of Redis keys for the buckets that cover the time window.
          # @api private
          def buckets_for_window(light_name, metric:, window_end:, window_size:)
            window_end_ts = window_end.to_i
            window_start_ts = window_end_ts - [window_size, Domain::DataStore::METRICS_RETENTION_TIME].compact.min.to_i

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
          # @param metric [String] The metric type (e.g., "errors").
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

        # @!attribute recovery_lock_store
        #   @return [Stoplight::Infrastructure::DataStore::Redis::RecoveryLockStore]
        protected attr_reader :recovery_lock_store

        # @!attribute scripting
        #   @return [Stoplight::Infrastructure::DataStore::Redis::Scripting]
        protected attr_reader :scripting

        # @!attribute redis
        #   @return [::Redis | ConnectionPool<::Redis>]
        protected attr_reader :redis

        # @!attribute warn_on_clock_skew
        #   @return [Boolean]
        protected attr_reader :warn_on_clock_skew

        # @param redis [::Redis, ConnectionPool<::Redis>]
        # @param recovery_lock_store [Stoplight::Infrastructure::DataStore::Redis::RecoveryLockStore]
        # @param warn_on_clock_skew [Boolean] (true) Whether to warn about clock skew between Redis and
        # @param scripting [Stoplight::Infrastructure::DataStore::Redis::Scripting]
        #   the application server
        def initialize(redis:, recovery_lock_store:, scripting:, warn_on_clock_skew: true)
          @warn_on_clock_skew = warn_on_clock_skew
          @redis = redis
          @recovery_lock_store = recovery_lock_store
          @scripting = scripting
        end

        def names
          metadata, recovery_metrics = @redis.then do |client|
            [
              [key("metadata", "*"), /^#{key("metadata", "")}/],
              [key("recovery_metrics", "*"), /^#{key("recovery_metrics", "")}/]
            ].map do |(pattern, prefix_regex)|
              client.scan_each(match: pattern).to_a.map do |key|
                key.sub(prefix_regex, "")
              end
            end
          end
          metadata + recovery_metrics
        end

        # @param config [Stoplight::Domain::Config]
        # @return [Stoplight::Domain::Metrics]
        def get_metrics(config)
          config.name

          window_end_ts = current_time.to_f
          window_start_ts = window_end_ts - config.window_size.to_i

          if config.window_size
            failure_keys = failure_bucket_keys(config, window_end: window_end_ts)
            success_keys = success_bucket_keys(config, window_end: window_end_ts)
          else
            failure_keys = []
            success_keys = []
          end

          successes, errors, last_success_at, last_error_json, consecutive_errors, consecutive_successes = scripting.call(
            :get_metrics,
            args: [
              failure_keys.count,
              window_start_ts,
              window_end_ts,
              "last_success_at", "last_error_json", "consecutive_errors", "consecutive_successes"
            ],
            keys: [
              metadata_key(config),
              *success_keys,
              *failure_keys
            ]
          )
          consecutive_errors = config.window_size ? [consecutive_errors.to_i, errors].min : consecutive_errors.to_i
          consecutive_successes = config.window_size ? [consecutive_successes.to_i, successes].min : consecutive_successes.to_i

          Domain::Metrics.new(
            successes: (successes if config.window_size),
            errors: (errors if config.window_size),
            consecutive_errors:,
            consecutive_successes:,
            last_error: deserialize_failure(last_error_json),
            last_success_at: (Time.at(last_success_at.to_f) if last_success_at)
          )
        end

        # @param config [Stoplight::Domain::Config]
        # @return [Stoplight::Domain::Metrics]
        def get_recovery_metrics(config)
          last_success_at, last_error_json, consecutive_errors, consecutive_successes = @redis.with do |client|
            client.hmget(
              recovery_metrics_key(config),
              "last_success_at", "last_error_json", "consecutive_errors", "consecutive_successes"
            )
          end

          Domain::Metrics.new(
            successes: nil, errors: nil,
            consecutive_errors: consecutive_errors.to_i,
            consecutive_successes: consecutive_successes.to_i,
            last_error: deserialize_failure(last_error_json),
            last_success_at: (Time.at(last_success_at.to_f) if last_success_at)
          )
        end

        # @return [Stoplight::Domain::StateSnapshot]
        def get_state_snapshot(config)
          detect_clock_skew

          breached_at_raw, locked_state, recovery_scheduled_after_raw, recovery_started_at_raw = @redis.with do |client|
            client.hmget(metadata_key(config), :breached_at, :locked_state, :recovery_scheduled_after, :recovery_started_at)
          end
          breached_at = breached_at_raw&.to_f
          recovery_scheduled_after = recovery_scheduled_after_raw&.to_f
          recovery_started_at = recovery_started_at_raw&.to_f

          Domain::StateSnapshot.new(
            breached_at: (Time.at(breached_at) if breached_at),
            locked_state: locked_state || Domain::State::UNLOCKED,
            recovery_scheduled_after: (Time.at(recovery_scheduled_after) if recovery_scheduled_after),
            recovery_started_at: (Time.at(recovery_started_at) if recovery_started_at),
            time: current_time
          )
        end

        def clear_metrics(config)
          if config.window_size
            window_end_ts = current_time.to_i
            @redis.with do |client|
              client.multi do |tx|
                tx.unlink(
                  *failure_bucket_keys(config, window_end: window_end_ts),
                  *success_bucket_keys(config, window_end: window_end_ts)
                )
                tx.hdel(metadata_key(config), "last_success_at", "last_error_json", "consecutive_errors", "consecutive_successes")
              end
            end
          else
            @redis.with do |client|
              client.hdel(metadata_key(config), "last_success_at", "last_error_json", "consecutive_errors", "consecutive_successes")
            end
          end
        end

        def clear_recovery_metrics(config)
          @redis.with do |client|
            client.del(recovery_metrics_key(config))
          end
        end

        private def state_snapshot_from_hash(data, time: current_time)
          breached_at = data[:breached_at]&.to_f
          recovery_scheduled_after = data[:recovery_scheduled_after]&.to_f
          recovery_started_at = data[:recovery_started_at]&.to_f

          Domain::StateSnapshot.new(
            breached_at: (Time.at(breached_at) if breached_at),
            locked_state: data[:locked_state] || Domain::State::UNLOCKED,
            recovery_scheduled_after: (Time.at(recovery_scheduled_after) if recovery_scheduled_after),
            recovery_started_at: (Time.at(recovery_started_at) if recovery_started_at),
            time:
          )
        end

        # @param config [Stoplight::Domain::Config] The light configuration.
        # @param exception [Exception]
        # @return [void]
        def record_failure(config, exception)
          current_time = self.current_time
          current_ts = current_time.to_f
          failure = Domain::Failure.from_error(exception, time: current_time)

          scripting.call(
            :record_failure,
            args: [current_ts, SecureRandom.hex(12), serialize_failure(failure), metrics_ttl, metadata_ttl],
            keys: [
              metadata_key(config),
              config.window_size && errors_key(config, time: current_ts)
            ].compact
          )
        end

        def record_success(config, request_id: SecureRandom.hex(12))
          current_ts = current_time.to_f

          scripting.call(
            :record_success,
            args: [current_ts, request_id, metrics_ttl, metadata_ttl],
            keys: [
              metadata_key(config),
              config.window_size && successes_key(config, time: current_ts)
            ].compact
          )
        end

        # Records a failed recovery probe for a specific light configuration.
        #
        # @param config [Stoplight::Domain::Config] The light configuration.
        # @param exception [Exception]
        # @return [void]
        def record_recovery_probe_failure(config, exception)
          current_time = self.current_time
          current_ts = current_time.to_f
          failure = Domain::Failure.from_error(exception, time: current_time)

          scripting.call(
            :record_recovery_probe_failure,
            args: [current_ts, serialize_failure(failure)],
            keys: [recovery_metrics_key(config)]
          )
        end

        # Records a successful recovery probe for a specific light configuration.
        #
        # @param config [Stoplight::Domain::Config] The light configuration.
        # @return [void]
        def record_recovery_probe_success(config)
          current_ts = current_time.to_f

          scripting.call(
            :record_recovery_probe_success,
            args: [current_ts],
            keys: [recovery_metrics_key(config)]
          )
        end

        def set_state(config, state)
          @redis.then do |client|
            client.hset(metadata_key(config), "locked_state", state)
          end
          state
        end

        def inspect
          "#<#{self.class.name} redis=#{@redis.inspect}>"
        end

        # Combined method that performs the state transition based on color
        #
        # @param config [Stoplight::Domain::Config] The light configuration
        # @param color [String] The color to transition to ("green", "yellow", or "red")
        # @return [Boolean] true if this is the first instance to detect this transition
        def transition_to_color(config, color)
          case color
          when Domain::Color::GREEN
            transition_to_green(config)
          when Domain::Color::YELLOW
            transition_to_yellow(config)
          when Domain::Color::RED
            transition_to_red(config)
          else
            raise ArgumentError, "Invalid color: #{color}"
          end
        end

        # @param config [Stoplight::Domain::Config]
        # @return [Stoplight::Infrastructure::DataStore::Redis::RecoveryLockToken, nil]
        def acquire_recovery_lock(config)
          recovery_lock_store.acquire_lock(config.name)
        end

        # @param lock [Stoplight::Infrastructure::DataStore::Redis::RecoveryLockToken]
        # @return [void]
        def release_recovery_lock(lock)
          recovery_lock_store.release_lock(lock)
        end

        # Transitions to GREEN state and ensures only one notification
        #
        # @param config [Stoplight::Domain::Config] The light configuration
        # @return [Boolean] true if this is the first instance to detect this transition
        private def transition_to_green(config)
          current_ts = current_time.to_f
          meta_key = metadata_key(config)

          became_green = scripting.call(
            :transition_to_green,
            args: [current_ts],
            keys: [meta_key]
          )
          became_green == 1
        end

        # Transitions to YELLOW (recovery) state and ensures only one notification
        #
        # @param config [Stoplight::Domain::Config] The light configuration
        # @return [Boolean] true if this is the first instance to detect this transition
        private def transition_to_yellow(config)
          current_ts = current_time.to_f
          meta_key = metadata_key(config)

          became_yellow = scripting.call(
            :transition_to_yellow,
            args: [current_ts],
            keys: [meta_key]
          )
          became_yellow == 1
        end

        # Transitions to RED state and ensures only one notification
        #
        # @param config [Stoplight::Domain::Config] The light configuration
        # @return [Boolean] true if this is the first instance to detect this transition
        private def transition_to_red(config)
          current_ts = current_time.to_f
          meta_key = metadata_key(config)
          recovery_scheduled_after_ts = current_ts + config.cool_off_time

          became_red = scripting.call(
            :transition_to_red,
            args: [current_ts, recovery_scheduled_after_ts],
            keys: [meta_key]
          )

          became_red == 1
        end

        # Removes all traces of a light from Redis metadata (metrics will expire by TTL).
        #
        # @param config [Stoplight::Domain::Config] The light configuration.
        # @return [void]
        def delete_light(config)
          @redis.then do |client|
            client.del(metadata_key(config), recovery_metrics_key(config))
          end
        end

        # @param failure_json [String, nil]
        # @return [Domain::Failure, nil]
        private def deserialize_failure(failure_json)
          return if failure_json.nil?

          object = JSON.parse(failure_json)
          error_object = object["error"]

          error_class = error_object["class"]
          error_message = error_object["message"]
          time = Time.at(object["time"])

          Domain::Failure.new(error_class, error_message, time)
        end

        # @param failure [Domain::Failure]
        # @return [String]
        private def serialize_failure(failure)
          JSON.generate(
            {
              error: {
                class: failure.error_class,
                message: failure.error_message
              },
              time: failure.time.to_f
            }
          )
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

        private def errors_key(config, time:)
          self.class.bucket_key(config.name, metric: "failure", time:)
        end

        private def recovery_metrics_key(config)
          key("recovery_metrics", config.name)
        end

        private def metadata_key(config)
          key("metadata", config.name)
        end

        METRICS_TTL = 86400 # 1 day
        private_constant :METRICS_TTL

        private def metrics_ttl
          METRICS_TTL
        end

        METADATA_TTL = 86400 * 7 # 7 days
        private_constant :METADATA_TTL

        private def metadata_ttl
          METADATA_TTL
        end

        SKEW_TOLERANCE = 5 # seconds
        private_constant :SKEW_TOLERANCE

        private def detect_clock_skew
          return unless @warn_on_clock_skew
          return unless should_sample?(0.01) # 1% chance

          redis_seconds, _redis_millis = @redis.then(&:time)
          app_seconds = current_time.to_i
          if (redis_seconds - app_seconds).abs > SKEW_TOLERANCE
            warn("Detected clock skew between Redis and the application server. Redis time: #{redis_seconds}, Application time: #{app_seconds}. See https://github.com/bolshakov/stoplight/wiki/Clock-Skew-and-Stoplight-Reliability")
          end
        end

        private def should_sample?(probability)
          rand <= probability
        end

        private def current_time
          Time.now
        end
      end
    end
  end
end
