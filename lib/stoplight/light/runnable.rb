# frozen_string_literal: true

module Stoplight
  class Light
    module Runnable # rubocop:disable Style/Documentation
      # @return [String]
      def state
        _, state = failures_and_state
        state
      end

      # @return [String]
      def color
        failures, state = failures_and_state
        failure = failures.first

        if state == State::LOCKED_GREEN then Color::GREEN
        elsif state == State::LOCKED_RED then Color::RED
        elsif failures.size < threshold then Color::GREEN
        elsif failure && Time.now - failure.time >= cool_off_time
          Color::YELLOW
        else
          Color::RED
        end
      end

      # @param fallback [#call, nil] (nil) a fallback block to be called when the light is red
      # @raise [Error::RedLight]
      def run(fallback = nil, &code)
        raise ArgumentError, 'nothing to run. Please, pass a block into `Light#run`' unless block_given?

        case color
        when Color::GREEN then run_green(fallback, &code)
        when Color::YELLOW then run_yellow(fallback, &code)
        else run_red(fallback)
        end
      end

      private

      def run_green(fallback, &code)
        on_failure = lambda do |size, error|
          notify(Color::GREEN, Color::RED, error) if failures_threshold_breached?(size, threshold)
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
        skip = configuration.skipped_errors.any? { |klass| klass === error }
        track = configuration.tracked_errors.any? { |klass| klass === error }

        !skip && track
      end

      def clear_failures
        safely([]) { data_store.clear_failures(self) }
      end

      def failures_and_state
        safely([[], State::UNLOCKED]) { data_store.get_all(self) }
      end

      def notify(from_color, to_color, error = nil)
        data_store.with_notification_lock(self, from_color, to_color) do
          notifiers.each do |notifier|
            safely { notifier.notify(self, from_color, to_color, error) }
          end
        end
      end

      def record_failure(error)
        failure = Failure.from_error(error)
        safely(0) { data_store.record_failure(self, failure) }
      end

      def safely(default = nil, &code)
        return yield if data_store == Default::DATA_STORE

        fallback = proc do |error|
          error_notifier.call(error) if error
          default
        end

        Stoplight("#{name}-safely")
          .with_data_store(Default::DATA_STORE)
          .run(fallback, &code)
      end
    end
  end
end
