# coding: utf-8

require 'minitest/spec'
require 'stoplight'

describe Stoplight::Color do
  it 'is a module' do
    Stoplight::Color.must_be_kind_of(Module)
  end

  describe '::GREEN' do
    it 'is a string' do
      Stoplight::Color::GREEN.must_be_kind_of(String)
    end

    it 'is frozen' do
      Stoplight::Color::GREEN.frozen?.must_equal(true)
    end
  end

  describe '::YELLOW' do
    it 'is a string' do
      Stoplight::Color::YELLOW.must_be_kind_of(String)
    end

    it 'is frozen' do
      Stoplight::Color::YELLOW.frozen?.must_equal(true)
    end
  end

  describe '::RED' do
    it 'is a string' do
      Stoplight::Color::RED.must_be_kind_of(String)
    end

    it 'is frozen' do
      Stoplight::Color::RED.frozen?.must_equal(true)
    end
  end
end
