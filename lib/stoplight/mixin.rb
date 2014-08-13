# coding: utf-8

module Stoplight
  module Mixin
    def stoplight(name, &block)
      Stoplight::Light.new(name, &block).run
    end
  end
end
