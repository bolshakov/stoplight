# frozen_string_literal: true

module Stoplight
  module DataStore
    class Redis
      # @api private
      module Lua
        RECORD_FAILURE = File.read(File.join(__dir__, "record_failure.lua"))
        RECORD_SUCCESS = File.read(File.join(__dir__, "record_success.lua"))
        GET_METADATA = File.read(File.join(__dir__, "get_metadata.lua"))
        TRANSITION_TO_YELLOW = File.read(File.join(__dir__, "transition_to_yellow.lua"))
        TRANSITION_TO_RED = File.read(File.join(__dir__, "transition_to_red.lua"))
        TRANSITION_TO_GREEN = File.read(File.join(__dir__, "transition_to_green.lua"))
      end
    end
  end
end
