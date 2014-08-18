# coding: utf-8

require 'forwardable'
require 'stoplight/data_store'
require 'stoplight/data_store/base'
require 'stoplight/data_store/memory'
require 'stoplight/data_store/redis'
require 'stoplight/error'
require 'stoplight/failure'
require 'stoplight/light'
require 'stoplight/mixin'
require 'stoplight/notifier'
require 'stoplight/notifier/base'
require 'stoplight/notifier/hip_chat'
require 'stoplight/notifier/standard_error'

module Stoplight
  # @return [Gem::Version]
  VERSION = Gem::Version.new('0.1.0')

  # @return [Integer]
  DEFAULT_THRESHOLD = 3

  # @return [Integer]
  DEFAULT_TIMEOUT = 5 * 60

  @data_store = DataStore::Memory.new
  @notifiers = [Notifier::StandardError.new]

  class << self
    extend Forwardable

    def_delegators :data_store, *%w(
      attempts
      clear_attempts
      clear_failures
      delete
      failures
      names
      purge
      record_attempt
      record_failure
      set_state
      set_threshold
      set_timeout
      state
    )

    # @return [DataStore::Base]
    attr_accessor :data_store

    # @return [Array<Notifier::Base>]
    attr_accessor :notifiers

    # @param name [String]
    # @return [Boolean]
    def green?(name)
      case data_store.state(name)
      when DataStore::STATE_LOCKED_GREEN
        true
      when DataStore::STATE_LOCKED_RED
        false
      else
        data_store.failures(name).size < threshold(name)
      end
    end

    # @param name [String]
    # @return (see .green?)
    def red?(name)
      !green?(name)
    end

    # @param name [String]
    # @return [Integer]
    def threshold(name)
      data_store.threshold(name) || DEFAULT_THRESHOLD
    end

    # @param name [String]
    # @return [Integer]
    def timeout(name)
      data_store.timeout(name) || DEFAULT_TIMEOUT
    end
  end
end
