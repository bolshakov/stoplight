# coding: utf-8

module Stoplight
  module Error
    Base = Class.new(StandardError)
    NoFallback = Class.new(Base)
    NoName = Class.new(Base)
    NoRedis = Class.new(Base)
  end
end
