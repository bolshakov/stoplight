# coding: utf-8

require 'json'

module Stoplight
  class Failure
    def initialize(error)
      @error = error
      @time = Time.now
    end

    def to_json
      JSON.dump(to_h)
    end

    private

    def to_h
      { error: @error.inspect, time: @time }
    end
  end
end
