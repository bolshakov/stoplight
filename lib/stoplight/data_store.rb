# coding: utf-8

module Stoplight
  module DataStore
    KEY_PREFIX = 'stoplight'

    STATES = Set.new([
      STATE_LOCKED_GREEN = 'locked_green',
      STATE_LOCKED_RED = 'locked_red',
      STATE_UNLOCKED = 'unlocked'
    ]).freeze
  end
end
