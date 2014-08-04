# coding: utf-8

module Stoplight
  module Errors
    Base = Class.new(StandardError)
    NoCode = Class.new(Base)
    NoFallback = Class.new(Base)
  end
end
