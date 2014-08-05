# coding: utf-8

module Stoplight
  module Error
    # @return [Class]
    Base = Class.new(StandardError)

    # @return [Class]
    NoCode = Class.new(Base)

    # @return [Class]
    NoFallback = Class.new(Base)

    # @return [Class]
    NoName = Class.new(Base)
  end
end
