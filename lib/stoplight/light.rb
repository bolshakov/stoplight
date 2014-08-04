# coding: utf-8

module Stoplight
  class Light
    attr_reader :name

    def initialize
      @name = caller_locations(1, 1).first.to_s
    end

    def with_code(&code)
      @code = code
      self
    end

    def with_fallback(&fallback)
      @fallback = fallback
      self
    end

    def with_name(name)
      @name = name
      self
    end

    def code
      return @code if defined?(@code)
      fail Errors::NoCode
    end

    def fallback
      return @fallback if defined?(@fallback)
      fail Errors::NoFallback
    end
  end
end
