# coding: utf-8

require 'json'

module Stoplight
  class Failure
    # @return [Time]
    attr_reader :time

    # @param error [Exception]
    def initialize(error)
      @error = error
      @time = Time.now
    end

    def to_json(*args)
      {
        error: @error.inspect,
        time: time.inspect
      }.to_json(*args)
    end
  end
end
