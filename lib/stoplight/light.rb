# coding: utf-8

module Stoplight
  class Light
    # @param data_store [DataStore::Base, nil]
    # @return [DataStore::Base]
    def self.data_store(data_store = nil)
      @data_store = data_store if data_store
      @data_store = DataStore::Memory.new unless defined?(@data_store)
      @data_store
    end

    # @yield []
    # @return [Light]
    def with_code(&code)
      @code = code
      self
    end

    # @yield []
    # @return [Light]
    def with_fallback(&fallback)
      @fallback = fallback
      self
    end

    # @param name [String]
    # @return [Light]
    def with_name(name)
      @name = name
      self
    end

    # @return [Proc]
    # @raise [Error::NoCode]
    def code
      return @code if defined?(@code)
      fail Error::NoCode
    end

    # @return [Proc]
    # @raise [Error::NoFallback]
    def fallback
      return @fallback if defined?(@fallback)
      fail Error::NoFallback
    end

    # @return [String]
    # @raise [Error::NoName]
    def name
      return @name if defined?(@name)
      fail Error::NoName
    end

    # @return [Object]
    # @raise (see #code)
    def run_code
      code.call
    rescue => error
      self.class.data_store.record_failure(name, error)
      raise error
    else
      self.class.data_store.clear_failures(name)
    end
  end
end
