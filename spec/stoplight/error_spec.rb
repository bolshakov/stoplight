# coding: utf-8

require 'minitest/spec'
require 'stoplight'

describe Stoplight::Error do
  it 'is a module' do
    Stoplight::Error.must_be_kind_of(Module)
  end

  describe '::Base' do
    it 'is a class' do
      Stoplight::Error::Base.must_be_kind_of(Class)
    end

    it 'is a subclass of StandardError' do
      Stoplight::Error::Base.must_be(:<, StandardError)
    end
  end

  describe '::RedLight' do
    it 'is a class' do
      Stoplight::Error::RedLight.must_be_kind_of(Class)
    end

    it 'is a subclass of StandardError' do
      Stoplight::Error::RedLight.must_be(:<, Stoplight::Error::Base)
    end
  end
end
