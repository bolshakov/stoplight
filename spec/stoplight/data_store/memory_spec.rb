# coding: utf-8

require 'minitest/spec'
require 'stoplight'

describe Stoplight::DataStore::Memory do
  let(:data_store) { Stoplight::DataStore::Memory.new }
  let(:light) { Stoplight::Light.new(name) {} }
  let(:name) { ('a'..'z').to_a.shuffle.join }

  it 'is a class' do
    Stoplight::DataStore::Memory.must_be_kind_of(Class)
  end

  it 'is a subclass of Base' do
    Stoplight::DataStore::Memory.must_be(:<, Stoplight::DataStore::Base)
  end

  describe '#get_all' do
    it 'returns the failures and the state' do
      failures, state = data_store.get_all(light)
      failures.must_equal([])
      state.must_equal(Stoplight::State::UNLOCKED)
    end
  end

  describe '#get_failures' do
    it 'is initially empty' do
      data_store.get_failures(light).must_equal([])
    end
  end

  describe '#record_failure' do
    it 'returns the number of failures' do
      failure = Stoplight::Failure.new('class', 'message', Time.new)
      data_store.record_failure(light, failure).must_equal(1)
    end

    it 'persists the failure' do
      failure = Stoplight::Failure.new('class', 'message', Time.new)
      data_store.record_failure(light, failure)
      data_store.get_failures(light).must_equal([failure])
    end

    it 'stores more recent failures at the front' do
      failure_1 = Stoplight::Failure.new('class', 'message 1', Time.new)
      data_store.record_failure(light, failure_1)
      failure_2 = Stoplight::Failure.new('class', 'message 2', Time.new)
      data_store.record_failure(light, failure_2)
      data_store.get_failures(light).must_equal([failure_2, failure_1])
    end

    it 'limits the number of stored failures' do
      light.with_threshold(1)
      failure_1 = Stoplight::Failure.new('class', 'message 1', Time.new)
      data_store.record_failure(light, failure_1)
      failure_2 = Stoplight::Failure.new('class', 'message 2', Time.new)
      data_store.record_failure(light, failure_2)
      data_store.get_failures(light).must_equal([failure_2])
    end
  end

  describe '#clear_failures' do
    it 'returns the failures' do
      failure = Stoplight::Failure.new('class', 'message', Time.new)
      data_store.record_failure(light, failure)
      data_store.clear_failures(light).must_equal([failure])
    end

    it 'clears the failures' do
      failure = Stoplight::Failure.new('class', 'message', Time.new)
      data_store.record_failure(light, failure)
      data_store.clear_failures(light)
      data_store.get_failures(light).must_equal([])
    end
  end

  describe '#get_state' do
    it 'is initially unlocked' do
      data_store.get_state(light).must_equal(Stoplight::State::UNLOCKED)
    end
  end

  describe '#set_state' do
    it 'returns the state' do
      state = 'state'
      data_store.set_state(light, state).must_equal(state)
    end

    it 'persists the state' do
      state = 'state'
      data_store.set_state(light, state)
      data_store.get_state(light).must_equal(state)
    end
  end

  describe '#clear_state' do
    it 'returns the state' do
      state = 'state'
      data_store.set_state(light, state)
      data_store.clear_state(light).must_equal(state)
    end

    it 'clears the state' do
      state = 'state'
      data_store.set_state(light, state)
      data_store.clear_state(light)
      data_store.get_state(light).must_equal(Stoplight::State::UNLOCKED)
    end
  end
end
