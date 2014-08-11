# coding: utf-8

module Stoplight
  module DataStore
    # @return [String]
    KEY_PREFIX = 'stoplight'

    # @return [Set<String>]
    STATES = Set.new([
      STATE_LOCKED_GREEN = 'locked_green',
      STATE_LOCKED_RED = 'locked_red',
      STATE_UNLOCKED = 'unlocked'
    ]).freeze
  end
end
