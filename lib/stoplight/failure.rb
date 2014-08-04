# coding: utf-8

module Stoplight
  class Failure
    # @return [Time]
    attr_reader :time

    def initialize
      @time = Time.now
    end
  end
end
