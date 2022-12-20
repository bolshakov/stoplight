# frozen_string_literal: true

module Stoplight
  class Light
    module Runnable # rubocop:disable Style/Documentation
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

      # @raise [Error::RedLight]
      def run(&code)
        code = validate_code(&code)
        case color
        when Color::GREEN then run_green(&code)
        when Color::YELLOW then run_yellow(&code)
        else run_red
        end
      end

      private

      def validate_code(&code)
        raise ArgumentError, <<~ERROR if block_given? && self.code
          passing code block into both `Light.new` and `Light#run` is not allowed
        ERROR

        raise ArgumentError, <<~ERROR unless block_given? || self.code
          nothing to run. Please, pass a block into `Light#run`
        ERROR

        code || self.code
      end

      def run_green(&code)
        on_failure = lambda do |size, error|
          notify(Color::GREEN, Color::RED, error) if failures_threshold_breached?(size, threshold)
        end
        run_code(nil, on_failure, &code)
      end

      def failures_threshold_breached?(current_failures_count, max_errors_threshold)
        current_failures_count == max_errors_threshold
      end

      def run_yellow(&code)
        on_success = lambda do |failures|
          notify(Color::RED, Color::GREEN) unless failures.empty?
        end
        run_code(on_success, nil, &code)
      end

      def run_red
        raise Error::RedLight, name unless fallback

        fallback.call(nil)
      end

      def run_code(on_success, on_failure, &code)
        result = code.call
        failures = clear_failures
        on_success&.call(failures)
        result
      rescue Exception => e # rubocop:disable Lint/RescueException
        handle_error(e, on_failure)
      end

      def handle_error(error, on_failure)
        error_handler.call(error, Error::HANDLER)
        size = record_failure(error)
        on_failure&.call(size, error)
        raise error unless fallback

        fallback.call(error)
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

        self
          .class
          .new("#{name}-safely")
          .with_data_store(Default::DATA_STORE)
          .with_fallback do |error|
            error_notifier.call(error) if error
            default
          end
          .run(&code)
      end
    end
  end
end
