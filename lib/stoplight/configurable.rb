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
      with(configuration: configuration.with(data_store: data_store))
    end

    # @param cool_off_time [Numeric]
    # @return [self]
    def with_cool_off_time(cool_off_time)
      with(configuration: configuration.with(cool_off_time: cool_off_time))
    end

    # @param threshold [Numeric]
    # @return [self]
    def with_threshold(threshold)
      with(configuration: configuration.with(threshold: threshold))
    end

    # @param window_size [Numeric]
    # @return [self]
    def with_window_size(window_size)
      with(configuration: configuration.with(window_size: window_size))
    end

    # @param notifiers [Array<Notifier::Base>]
    # @return [self]
    def with_notifiers(notifiers)
      with(configuration: configuration.with(notifiers: notifiers))
    end

    # @param error_notifier [Proc]
    # @return [self]
    def with_error_notifier(&error_notifier)
      with(configuration: configuration.with(error_notifier: error_notifier))
    end

    # @param [Stoplight::Configuration]
    # @return [self]
    def with(configuration:)
      raise NotImplementedError
    end
  end
end
