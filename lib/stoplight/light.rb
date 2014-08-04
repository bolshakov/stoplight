# coding: utf-8

module Stoplight
  class Light
    # @return [String]
    attr_reader :name

    def initialize
      @name = caller_locations(1, 1).first.to_s
    end

    # @yield []
    # @return [Light]
    def with_code(&code)
      @code = code
      self
    end

    # @yield []
    # @return [Light]
    def with_fallback(&fallback)
      @fallback = fallback
      self
    end

    # @param name [String]
    # @return [Light]
    def with_name(name)
      @name = name
      self
    end

    # @return [Proc]
    # @raise [Errors::NoCode]
    def code
      return @code if defined?(@code)
      fail Errors::NoCode
    end

    # @return [Proc]
    # @raise [Errors::NoFallback]
    def fallback
      return @fallback if defined?(@fallback)
      fail Errors::NoFallback
    end
  end
end
