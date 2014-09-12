# coding: utf-8

require 'json'

module Stoplight
  class Failure
    # @return [String]
    attr_reader :error_class

    # @return [String]
    attr_reader :error_message

    # @return [Time]
    attr_reader :time

    # @param json [String]
    def self.from_json(json)
      h = JSON.parse(json)
      new(
        h['error']['class'],
        h['error']['message'],
        Time.parse(h['time']))
    rescue => error
      new(Error::InvalidFailure.name, error.message)
    end

    # @param error_class [String]
    # @param error_message [String]
    # @param time [Time, nil]
    def initialize(error_class, error_message, time = nil)
      @error_class = error_class
      @error_message = error_message
      @time = time || Time.now
    end

    def to_json(*args)
      {
        error: {
          class: error_class,
          message: error_message
        },
        time: time.inspect
      }.to_json(*args)
    end
  end
end
