# coding: utf-8

module Stoplight
  module DataStore
    class Test < Memory
      def get_state(light)
        # always green
        State::LOCKED_GREEN
      end
    end
  end
end
