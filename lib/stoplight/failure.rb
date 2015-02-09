# coding: utf-8

require 'multi_json'
require 'time'

module Stoplight
  class Failure
    attr_reader :error_class
    attr_reader :error_message
    attr_reader :time

    def self.from_error(error)
      new(error.class.name, error.message, Time.new)
    end

    def self.from_json(json)
      object = MultiJson.load(json)

      error_class = object['error']['class']
      error_message = object['error']['message']
      time = Time.parse(object['time'])

      new(error_class, error_message, time)
    end

    def initialize(error_class, error_message, time)
      @error_class = error_class
      @error_message = error_message
      @time = time
    end

    def ==(other)
      error_class == other.error_class &&
        error_message == other.error_message &&
        time == other.time
    end

    def to_json
      MultiJson.dump(
        error: {
          class: error_class,
          message: error_message
        },
        time: time.strftime('%Y-%m-%dT%H:%M:%S.%N%:z')
      )
    end
  end
end
