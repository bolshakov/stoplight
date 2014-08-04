# coding: utf-8

module Stoplight
  module Errors
    Base = Class.new(StandardError)
    NoCode = Class.new(Base)
  end
end
