# frozen_string_literal: true

module Stoplight
  module DataStore
    class Redis
      # @api private
      module Lua
        class << self
          def read_lua_file(name_without_extension)
            File.read(File.join(__dir__, "#{name_without_extension}.lua"))
          end
        end

        RECORD_FAILURE = read_lua_file("record_failure")
        RECORD_SUCCESS = read_lua_file("record_success")
        GET_METADATA = read_lua_file("get_metadata")
        TRANSITION_TO_YELLOW = read_lua_file("transition_to_yellow")
        TRANSITION_TO_RED = read_lua_file("transition_to_red")
        TRANSITION_TO_GREEN = read_lua_file("transition_to_green")
      end
    end
  end
end
