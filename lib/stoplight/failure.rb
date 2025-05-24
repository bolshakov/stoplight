# frozen_string_literal: true

require "json"
require "time"

module Stoplight
  class Failure # rubocop:disable Style/Documentation
    TIME_FORMAT = "%Y-%m-%dT%H:%M:%S.%N%:z"

    # @return [String]
    attr_reader :error_class
    # @return [String]
    attr_reader :error_message
    # @return [Time]
    attr_reader :time

    # @param error [Exception]
    # @return (see #initialize)
    def self.from_error(error, time: Time.now)
      new(error.class.name, error.message, time)
    end

    # @param json [String]
    # @return (see #initialize)
    # @raise [JSON::ParserError]
    # @raise [ArgumentError]
    def self.from_json(json)
      object = JSON.parse(json)
      error_object = object["error"]

      error_class = error_object["class"]
      error_message = error_object["message"]
      time = Time.at(object["time"])

      new(error_class, error_message, time)
    end

    # @param error_class [String]
    # @param error_message [String]
    # @param time [Time]
    def initialize(error_class, error_message, time)
      @error_class = error_class
      @error_message = error_message
      @time = Time.at(time.to_i) # truncate to seconds
    end

    # @param other [Failure]
    # @return [Boolean]
    def ==(other)
      other.is_a?(self.class) &&
        error_class == other.error_class &&
        error_message == other.error_message &&
        time.to_i == other.time.to_i
    end

    # @param options [Object, nil]
    # @return [String]
    def to_json(options = nil)
      JSON.generate(
        {
          error: {
            class: error_class,
            message: error_message
          },
          time: time.to_i
        },
        options
      )
    end
  end
end
