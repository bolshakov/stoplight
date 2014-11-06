# coding: utf-8
# rubocop:disable Metrics/ClassLength

require 'json'

module Stoplight
  module DataStore
    class Redis < Base
      def initialize(redis)
        @redis = redis
      end

      def names
        @redis.hkeys(DataStore.thresholds_key)
      end

      def clear_stale
        names
          .select { |name| get_failures(name).empty? }
          .each { |name| clear(name) }
      end

      def clear(name)
        @redis.pipelined do
          clear_attempts(name)
          clear_failures(name)
          clear_state(name)
          clear_threshold(name)
          clear_timeout(name)
        end
      end

      def sync(name)
        threshold = @redis.hget(DataStore.thresholds_key, name)
        threshold = normalize_threshold(threshold)
        @redis.hset(DataStore.thresholds_key, name, threshold)
      rescue ::Redis::BaseError => error
        raise Error::BadDataStore, error
      end

      def greenify(name)
        @redis.pipelined do
          clear_attempts(name)
          clear_failures(name)
        end
      end

      def get_color(name)
        DataStore.colorize(*colorize_args(name))
      end

      def get_attempts(name)
        normalize_attempts(@redis.hget(DataStore.attempts_key, name))
      end

      def record_attempt(name)
        @redis.hincrby(DataStore.attempts_key, name, 1)
      end

      def clear_attempts(name)
        @redis.hdel(DataStore.attempts_key, name)
      end

      def get_failures(name)
        normalize_failures(@redis.lrange(DataStore.failures_key(name), 0, -1))
      end

      def record_failure(name, failure)
        DataStore.validate_failure!(failure)
        @redis.rpush(DataStore.failures_key(name), failure.to_json)
      end

      def clear_failures(name)
        @redis.del(DataStore.failures_key(name))
      end

      def get_state(name)
        normalize_state(@redis.hget(DataStore.states_key, name))
      end

      def set_state(name, state)
        DataStore.validate_state!(state)
        @redis.hset(DataStore.states_key, name, state)
        state
      end

      def clear_state(name)
        @redis.hdel(DataStore.states_key, name)
      end

      def get_threshold(name)
        normalize_threshold(@redis.hget(DataStore.thresholds_key, name))
      end

      def set_threshold(name, threshold)
        DataStore.validate_threshold!(threshold)
        @redis.hset(DataStore.thresholds_key, name, threshold)
        threshold
      end

      def clear_threshold(name)
        @redis.hdel(DataStore.thresholds_key, name)
      end

      def get_timeout(name)
        normalize_timeout(@redis.hget(DataStore.timeouts_key, name))
      end

      def set_timeout(name, timeout)
        DataStore.validate_timeout!(timeout)
        @redis.hset(DataStore.timeouts_key, name, timeout)
        timeout
      end

      def clear_timeout(name)
        @redis.hdel(DataStore.timeouts_key, name)
      end

      private

      def colorize_args(name)
        state, threshold, failures, timeout = @redis.pipelined do
          @redis.hget(DataStore.states_key, name)
          @redis.hget(DataStore.thresholds_key, name)
          @redis.lrange(DataStore.failures_key(name), 0, -1)
          @redis.hget(DataStore.timeouts_key, name)
        end
        normalize_colorize_args(state, threshold, failures, timeout)
      end

      def normalize_colorize_args(state, threshold, failures, timeout)
        [
          normalize_state(state),
          normalize_threshold(threshold),
          normalize_failures(failures),
          normalize_timeout(timeout)
        ]
      end

      # @param attempts [String, nil]
      # @return [Integer]
      def normalize_attempts(attempts)
        attempts ? attempts.to_i : DEFAULT_ATTEMPTS
      end

      # @param failures [Array<String>]
      # @return [Array<Failure>]
      def normalize_failures(failures)
        failures.map { |json| Failure.from_json(json) }
      end

      # @param state [String, nil]
      # @return [String]
      def normalize_state(state)
        state || DEFAULT_STATE
      end

      # @param threshold [String, nil]
      # @return [Integer]
      def normalize_threshold(threshold)
        threshold ? threshold.to_i : DEFAULT_THRESHOLD
      end

      # @param timeout [String, nil]
      # @return [Integer]
      def normalize_timeout(timeout)
        timeout ? timeout.to_i : DEFAULT_TIMEOUT
      end
    end
  end
end
