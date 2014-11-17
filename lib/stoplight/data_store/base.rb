# coding: utf-8

module Stoplight
  module DataStore
    class Base
      def names
        fail NotImplementedError
      end

      def get_all(_light)
        fail NotImplementedError
      end

      def get_failures(_light)
        fail NotImplementedError
      end

      def record_failure(_light, _failure)
        fail NotImplementedError
      end

      def clear_failures(_light)
        fail NotImplementedError
      end

      def get_state(_light)
        fail NotImplementedError
      end

      def set_state(_light, _state)
        fail NotImplementedError
      end

      def clear_state(_light)
        fail NotImplementedError
      end
    end
  end
end
