# coding: utf-8

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
  VERSION = Gem::Version.new('0.2.1')

  @data_store = DataStore::Memory.new
  @notifiers = [Notifier::StandardError.new]

  class << self
    # @return [DataStore::Base]
    attr_accessor :data_store

    # @return [Array<Notifier::Base>]
    attr_accessor :notifiers
  end
end
