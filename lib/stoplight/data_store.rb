# coding: utf-8

module Stoplight
  module DataStore
    KEY_PREFIX = 'stoplight'.freeze

    COLOR_GREEN = 'green'.freeze
    COLOR_YELLOW = 'yellow'.freeze
    COLOR_RED = 'red'.freeze
    COLORS = Set.new([
      COLOR_GREEN,
      COLOR_YELLOW,
      COLOR_RED
    ]).freeze

    STATE_UNLOCKED = 'unlocked'.freeze
    STATE_LOCKED_GREEN = 'locked_green'.freeze
    STATE_LOCKED_RED = 'locked_red'.freeze
    STATES = Set.new([
      STATE_UNLOCKED,
      STATE_LOCKED_GREEN,
      STATE_LOCKED_RED
    ]).freeze

    DEFAULT_ATTEMPTS = 0
    DEFAULT_FAILURES = []
    DEFAULT_STATE = STATE_UNLOCKED
    DEFAULT_THRESHOLD = 3
    DEFAULT_TIMEOUT = 60

    module_function

    # @group Colors

    # @param state [String]
    # @param threshold [Integer]
    # @param failures [Array<Failure>]
    # @param timeout [Integer]
    # @return [String]
    def colorize(state, threshold, failures, timeout)
      case
      when state == STATE_LOCKED_GREEN then COLOR_GREEN
      when state == STATE_LOCKED_RED then COLOR_RED
      when threshold < 1 then COLOR_RED
      when failures.size < threshold then COLOR_GREEN
      when Time.now - failures.last.time > timeout then COLOR_YELLOW
      else COLOR_RED
      end
    end

    # @group Validation

    # @param color [String]
    # @raise [ArgumentError]
    def validate_color!(color)
      return if valid_color?(color)
      fail ArgumentError, "invalid color: #{color.inspect}"
    end

    # @param color [String]
    # @return [Boolean]
    def valid_color?(color)
      COLORS.include?(color)
    end

    # @param failure [Failure]
    # @raise [ArgumentError]
    def validate_failure!(failure)
      return if valid_failure?(failure)
      fail ArgumentError, "invalid failure: #{failure.inspect}"
    end

    # @param failure [Failure]
    # @return [Boolean]
    def valid_failure?(failure)
      failure.is_a?(Failure)
    end

    # @param state [String]
    # @raise [ArgumentError]
    def validate_state!(state)
      return if valid_state?(state)
      fail ArgumentError, "invalid state: #{state.inspect}"
    end

    # @param state [String]
    # @return [Boolean]
    def valid_state?(state)
      STATES.include?(state)
    end

    # @param threshold [Integer]
    # @raise [ArgumentError]
    def validate_threshold!(threshold)
      return if valid_threshold?(threshold)
      fail ArgumentError, "invalid threshold: #{threshold.inspect}"
    end

    # @param threshold [Integer]
    # @return [Boolean]
    def valid_threshold?(threshold)
      threshold.is_a?(Integer)
    end

    # @param timeout [Integer]
    # @raise [ArgumentError]
    def validate_timeout!(timeout)
      return if valid_timeout?(timeout)
      fail ArgumentError, "invalid timeout: #{timeout.inspect}"
    end

    # @param timeout [Integer]
    # @return [Boolean]
    def valid_timeout?(timeout)
      timeout.is_a?(Integer)
    end

    # @group Keys

    # @return (see #key)
    def attempts_key
      key('attempts')
    end

    # @param name [String]
    # @return (see #key)
    def failures_key(name)
      key('failures', name)
    end

    # @return (see #key)
    def states_key
      key('states')
    end

    # @return (see #key)
    def thresholds_key
      key('thresholds')
    end

    # @return (see #key)
    def timeouts_key
      key('timeouts')
    end

    # @param slug [String]
    # @param suffix [String, nil]
    # @return [String]
    def key(slug, suffix = nil)
      [KEY_PREFIX, slug, suffix].compact.join(':')
    end
  end
end
