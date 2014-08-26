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

    # @return [String]
    COLOR_GREEN = 'green'.freeze

    # @return [String]
    COLOR_YELLOW = 'yellow'.freeze

    # @return [String]
    COLOR_RED = 'red'.freeze

    # @return [Integer]
    DEFAULT_TIMEOUT = 5 * 60

    # @return [Integer]
    DEFAULT_THRESHOLD = 3
  end
end
