# frozen_string_literal: true

require 'forwardable'

module Stoplight
  # An immutable +Stoplight::Light+ configuration object that could be
  # shared between different lights.
  class Configuration
    extend Forwardable

    def_delegator :light, :with_error_handler
    def_delegator :light, :with_error_notifier
    def_delegator :light, :with_fallback
    def_delegator :light, :color
    def_delegator :light, :run
    def_delegator :light, :lock
    def_delegator :light, :unlock

    # @!attribute name
    #   @return [String]
    attr_reader :name

    # @!attribute data_store
    #   @return [Stoplight::DataStore::Base]
    attr_reader :data_store

    # @!attribute cool_off_time
    #   @return [Fixnum]
    attr_reader :cool_off_time

    # @!attribute threshold
    #   @return [Integer]
    attr_reader :threshold

    # @!attribute window_size
    #   @return [Float]
    attr_reader :window_size

    # @!attribute notifiers
    #   # @return [Array<Notifier::Base>]
    attr_reader :notifiers

    class << self
      # @return [DataStore::Base]
      attr_accessor :default_data_store
      # @return [Array<Notifier::Base>]
      attr_accessor :default_notifiers
    end

    @default_data_store = Default::DATA_STORE
    @default_notifiers = Default::NOTIFIERS

    # @param name [String]
    def initialize(
      name,
      cool_off_time: Default::COOL_OFF_TIME,
      threshold: Default::THRESHOLD,
      window_size: Default::WINDOW_SIZE,
      data_store: self.class.default_data_store,
      notifiers: self.class.default_notifiers
    )
      @name = name
      @data_store = data_store
      @notifiers = notifiers
      @cool_off_time = cool_off_time
      @threshold = threshold
      @window_size = window_size
    end

    # @param name [String]
    # @return [Stoplight::Configuration]
    def with_name(name)
      copy(name: name)
    end
    private :with_name

    # @param data_store [DataStore::Base]
    # @return [Stoplight::Configuration]
    def with_data_store(data_store)
      copy(data_store: data_store)
    end

    # @param cool_off_time [Float]
    # @return [Stoplight::Configuration]
    def with_cool_off_time(cool_off_time)
      copy(cool_off_time: cool_off_time)
    end

    # @param threshold [Fixnum]
    # @return [Stoplight::Configuration]
    def with_threshold(threshold)
      copy(threshold: threshold)
    end

    # @param window_size [Integer]
    # @return [Stoplight::Configuration]
    def with_window_size(window_size)
      copy(window_size: window_size)
    end

    # @param notifiers [Array<Notifier::Base>]
    # @return [Stoplight::Configuration]
    def with_notifiers(notifiers)
      copy(notifiers: notifiers)
    end

    private

    def light
      Light.new(name, self)
    end

    # @param cool_off_time [Float]
    # @param threshold [Fixnum]
    # @param window_size [Integer]
    # @return [Stoplight::Configuration]
    def copy(
      name: self.name,
      cool_off_time: self.cool_off_time,
      threshold: self.threshold,
      window_size: self.window_size,
      data_store: self.data_store,
      notifiers: self.notifiers
    )
      Configuration.new(
        name,
        data_store: data_store,
        notifiers: notifiers,
        cool_off_time: cool_off_time,
        threshold: threshold,
        window_size: window_size
      )
    end
  end
end
