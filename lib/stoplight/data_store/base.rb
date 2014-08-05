# coding: utf-8

module Stoplight
  module DataStore
    # @abstract
    class Base
      # @param key [Object]
      # @return [Object, nil]
      def read(_key)
        fail NotImplementedError
      end
    end
  end
end
