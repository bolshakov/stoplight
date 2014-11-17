# coding: utf-8

require 'minitest/spec'
require 'stoplight'

describe Stoplight::DataStore::Base do
  it 'is a class' do
    Stoplight::DataStore::Base.must_be_kind_of(Class)
  end

  describe '#get_all' do
    it 'is not implemented' do
      -> { Stoplight::DataStore::Base.new.get_all(nil) }
        .must_raise(NotImplementedError)
    end
  end

  describe '#get_failures' do
    it 'is not implemented' do
      -> { Stoplight::DataStore::Base.new.get_failures(nil) }
        .must_raise(NotImplementedError)
    end
  end

  describe '#record_failure' do
    it 'is not implemented' do
      -> { Stoplight::DataStore::Base.new.record_failure(nil, nil) }
        .must_raise(NotImplementedError)
    end
  end

  describe '#clear_failures' do
    it 'is not implemented' do
      -> { Stoplight::DataStore::Base.new.clear_failures(nil) }
        .must_raise(NotImplementedError)
    end
  end

  describe '#get_state' do
    it 'is not implemented' do
      -> { Stoplight::DataStore::Base.new.get_state(nil) }
        .must_raise(NotImplementedError)
    end
  end

  describe '#set_state' do
    it 'is not implemented' do
      -> { Stoplight::DataStore::Base.new.set_state(nil, nil) }
        .must_raise(NotImplementedError)
    end
  end

  describe '#clear_state' do
    it 'is not implemented' do
      -> { Stoplight::DataStore::Base.new.clear_state(nil) }
        .must_raise(NotImplementedError)
    end
  end
end
