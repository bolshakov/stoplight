# frozen_string_literal: true

module Stoplight
  class Light < CircuitBreaker
    module Runnable # rubocop:disable Style/Documentation
      # @return [String]
      def state
        safely(State::UNLOCKED) do
          config.data_store.get_state(config)
        end
      end

      # Returns current color:
      #   * +Stoplight::Color::GREEN+ -- circuit breaker is closed
      #   * +Stoplight::Color::RED+ -- circuit breaker is open
      #   * +Stoplight::Color::YELLOW+ -- circuit breaker is half-open
      #
      # @example
      #   light = Stoplight('example')
      #   light.color #=> Color::GREEN
      #
      # @return [String] returns current light color
      def color
        failures, state = failures_and_state
        failure = failures.first

        if state == State::LOCKED_GREEN then Color::GREEN
        elsif state == State::LOCKED_RED then Color::RED
        elsif failures.size < config.threshold then Color::GREEN
        elsif failure && Time.now - failure.time >= config.cool_off_time
          Color::YELLOW
        else
          Color::RED
        end
      end

      # Runs the given block of code with this circuit breaker
      #
      # @example
      #   light = Stoplight('example')
      #   light.run { 2/0 }
      #
      # @example Running with fallback
      #   light = Stoplight('example')
      #   light.run(->(error) { 0 }) { 1 / 0 } #=> 0
      #
      # @param fallback [Proc, nil] (nil) fallback code to run if the circuit breaker is open
      # @raise [Stoplight::Error::RedLight]
      # @return [any]
      # @raise [Error::RedLight]
      def run(fallback = nil, &code)
        raise ArgumentError, "nothing to run. Please, pass a block into `Light#run`" unless block_given?

        case color
        when Color::GREEN then run_green(fallback, &code)
        when Color::YELLOW then run_yellow(fallback, &code)
        else run_red(fallback)
        end
      end

      private

      def run_green(fallback, &code)
        on_failure = lambda do |size, error|
          notify(Color::GREEN, Color::RED, error) if failures_threshold_breached?(size, config.threshold)
        end
        run_code(nil, on_failure, fallback, &code)
      end

      def failures_threshold_breached?(current_failures_count, max_errors_threshold)
        current_failures_count == max_errors_threshold
      end

      def run_yellow(fallback, &code)
        on_success = lambda do |failures|
          notify(Color::RED, Color::GREEN) unless failures.empty?
        end
        run_code(on_success, nil, fallback, &code)
      end

      # @param fallback [#call, nil]
      def run_red(fallback)
        raise Error::RedLight, name unless fallback

        fallback.call(nil)
      end

      def run_code(on_success, on_failure, fallback, &code)
        result = code.call
        failures = clear_failures
        on_success&.call(failures)
        result
      rescue Exception => e # rubocop:disable Lint/RescueException
        handle_error(e, on_failure, fallback)
      end

      def handle_error(error, on_failure, fallback)
        raise error unless handle_error?(error)

        size = record_failure(error)
        on_failure&.call(size, error)
        raise error unless fallback

        fallback.call(error)
      end

      def handle_error?(error)
        skip = config.skipped_errors.any? { |klass| klass === error }
        track = config.tracked_errors.any? { |klass| klass === error }

        !skip && track
      end

      def clear_failures
        safely([]) { config.data_store.clear_failures(config) }
      end

      def failures_and_state
        safely([[], State::UNLOCKED]) { config.data_store.get_all(config) }
      end

      def notify(from_color, to_color, error = nil)
        config.data_store.with_deduplicated_notification(config, from_color, to_color) do
          config.notifiers.each do |notifier|
            safely { notifier.notify(self, from_color, to_color, error) }
          end
        end
      end

      def record_failure(error)
        failure = Failure.from_error(error)
        safely(0) { config.data_store.record_failure(config, failure) }
      end

      def safely(default = nil, &code)
        return yield if config.data_store == Default::DATA_STORE

        fallback = proc do |error|
          config.error_notifier.call(error) if error
          default
        end

        Stoplight("#{name}-safely")
          .with_data_store(Default::DATA_STORE)
          .run(fallback, &code)
      end
    end
  end
end
