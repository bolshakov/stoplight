# coding: utf-8

require 'json'

module Stoplight
  class Failure
    # @return [Exception]
    attr_reader :error

    # @return [Time]
    attr_reader :time

    def self.from_json(json)
      h = JSON.parse(json)

      match = /#<(.+): (.+)>/.match(h['error'])
      error = Object.const_get(match[1]).new(match[2]) if match

      time = Time.parse(h['time'])

      new(error, time)
    end

    # @param error [Exception]
    def initialize(error, time = nil)
      @error = error
      @time = time || Time.now
    end

    def to_json(*args)
      {
        error: @error.inspect,
        time: time.inspect
      }.to_json(*args)
    end
  end
end
