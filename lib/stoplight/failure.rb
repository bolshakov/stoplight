# coding: utf-8

module Stoplight
  class Failure
    # @return [Time]
    attr_reader :time
    # @return [Exception]
    attr_reader :error

    def initialize(error)
      @time = Time.now
      @error = error
    end
  end
end
