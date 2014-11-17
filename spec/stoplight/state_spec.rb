# coding: utf-8

require 'minitest/spec'
require 'stoplight'

describe Stoplight::State do
  it 'is a module' do
    Stoplight::State.must_be_kind_of(Module)
  end

  describe '::UNLOCKED' do
    it 'is a string' do
      Stoplight::State::UNLOCKED.must_be_kind_of(String)
    end

    it 'is frozen' do
      Stoplight::State::UNLOCKED.frozen?.must_equal(true)
    end
  end

  describe '::LOCKED_GREEN' do
    it 'is a string' do
      Stoplight::State::LOCKED_GREEN.must_be_kind_of(String)
    end

    it 'is frozen' do
      Stoplight::State::LOCKED_GREEN.frozen?.must_equal(true)
    end
  end

  describe '::LOCKED_RED' do
    it 'is a string' do
      Stoplight::State::LOCKED_RED.must_be_kind_of(String)
    end

    it 'is frozen' do
      Stoplight::State::LOCKED_RED.frozen?.must_equal(true)
    end
  end
end
