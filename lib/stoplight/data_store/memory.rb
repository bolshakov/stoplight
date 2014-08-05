# coding: utf-8

module Stoplight
  module DataStore
    class Memory < Base
      def initialize
        @data = {}
      end

      def [](key)
        @data[key]
      end

      def write(key, value)
        @data[key] = value
      end
    end
  end
end
