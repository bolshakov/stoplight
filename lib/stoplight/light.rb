# coding: utf-8

module Stoplight
  class Light
    def with_code(&block)
      @code = block
      self
    end

    def code
      return @code if defined?(@code)
      fail NotImplementedError
    end
  end
end
