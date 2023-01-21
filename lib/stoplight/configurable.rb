# frozen_string_literal: true

module Stoplight
  # @api private
  # @abstract define +#with+ method
  module Configurable
    # @!attribute configuration
    #   @return [Stoplight::Configuration]
    attr_reader :configuration

    # @param data_store [DataStore::Base]
    # @return [self]
    def with_data_store(data_store)
      reconfigure(configuration.with(data_store: data_store))
    end

    # @param cool_off_time [Numeric]
    # @return [self]
    def with_cool_off_time(cool_off_time)
      reconfigure(configuration.with(cool_off_time: cool_off_time))
    end

    # @param threshold [Numeric]
    # @return [self]
    def with_threshold(threshold)
      reconfigure(configuration.with(threshold: threshold))
    end

    # @param window_size [Numeric]
    # @return [self]
    def with_window_size(window_size)
      reconfigure(configuration.with(window_size: window_size))
    end

    # @param notifiers [Array<Notifier::Base>]
    # @return [self]
    def with_notifiers(notifiers)
      reconfigure(configuration.with(notifiers: notifiers))
    end

    # @param error_notifier [Proc]
    # @return [self]
    def with_error_notifier(&error_notifier)
      reconfigure(configuration.with(error_notifier: error_notifier))
    end

    private

    # @param [Stoplight::Configuration]
    # @return [self]
    def reconfigure(_configuration)
      raise NotImplementedError, "#{self.class.name}#reconfigure is not implemented"
    end
  end
end
