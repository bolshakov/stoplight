# coding: utf-8

module Stoplight
  class Light
    def with_code(&block)
      @code = block
      self
    end
  end
end
