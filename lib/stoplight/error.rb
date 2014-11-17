# coding: utf-8

module Stoplight
  module Error
    Base = Class.new(StandardError)
    RedLight = Class.new(Base)
  end
end
