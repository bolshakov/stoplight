# coding: utf-8

module Stoplight
  module DataStore
    # @abstract
    class Base
      # @return [Array<String>]
      def names
        fail NotImplementedError
      end

      # @param _light [Light]
      # @return [Array(Array<Failure>, String)]
      def get_all(_light)
        fail NotImplementedError
      end

      # @param _light [Light]
      # @return [Array<Failure>]
      def get_failures(_light)
        fail NotImplementedError
      end

      # @param _light [Light]
      # @param _failure [Failure]
      # @return [Fixnum]
      def record_failure(_light, _failure)
        fail NotImplementedError
      end

      # @param _light [Light]
      # @return [Array<Failure>]
      def clear_failures(_light)
        fail NotImplementedError
      end

      # @param _light [Light]
      # @return [String]
      def get_state(_light)
        fail NotImplementedError
      end

      # @param _light [Light]
      # @param _state [String]
      # @return [String]
      def set_state(_light, _state)
        fail NotImplementedError
      end

      # @param _light [Light]
      # @return [String]
      def clear_state(_light)
        fail NotImplementedError
      end
    end
  end
end
