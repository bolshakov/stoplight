# coding: utf-8

require 'json'

module Stoplight
  class Failure
    attr_reader :time
    attr_reader :error

    def initialize(error)
      @time = Time.now
      @error = error
    end

    def to_h
      {
        time: time,
        error: error.inspect
      }
    end

    def to_json
      JSON.dump(to_h)
    end
  end
end
