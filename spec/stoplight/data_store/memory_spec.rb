# coding: utf-8

require 'spec_helper'

describe Stoplight::DataStore::Memory do
  let(:data_store) { described_class.new }
  let(:light) { Stoplight::Light.new(name) {} }
  let(:name) { ('a'..'z').to_a.shuffle.join }

  it 'is a class' do
    expect(described_class).to be_a(Class)
  end

  it 'is a subclass of Base' do
    expect(described_class).to be < Stoplight::DataStore::Base
  end

  describe '#get_all' do
    it 'returns the failures and the state' do
      failures, state = data_store.get_all(light)
      expect(failures).to eql([])
      expect(state).to eql(Stoplight::State::UNLOCKED)
    end
  end

  describe '#get_failures' do
    it 'is initially empty' do
      expect(data_store.get_failures(light)).to eql([])
    end
  end

  describe '#record_failure' do
    it 'returns the number of failures' do
      failure = Stoplight::Failure.new('class', 'message', Time.new)
      expect(data_store.record_failure(light, failure)).to eql(1)
    end

    it 'persists the failure' do
      failure = Stoplight::Failure.new('class', 'message', Time.new)
      data_store.record_failure(light, failure)
      expect(data_store.get_failures(light)).to eql([failure])
    end

    it 'stores more recent failures at the front' do
      failure_1 = Stoplight::Failure.new('class', 'message 1', Time.new)
      data_store.record_failure(light, failure_1)
      failure_2 = Stoplight::Failure.new('class', 'message 2', Time.new)
      data_store.record_failure(light, failure_2)
      expect(data_store.get_failures(light)).to eql([failure_2, failure_1])
    end

    it 'limits the number of stored failures' do
      light.with_threshold(1)
      failure_1 = Stoplight::Failure.new('class', 'message 1', Time.new)
      data_store.record_failure(light, failure_1)
      failure_2 = Stoplight::Failure.new('class', 'message 2', Time.new)
      data_store.record_failure(light, failure_2)
      expect(data_store.get_failures(light)).to eql([failure_2])
    end
  end

  describe '#clear_failures' do
    it 'returns the failures' do
      failure = Stoplight::Failure.new('class', 'message', Time.new)
      data_store.record_failure(light, failure)
      expect(data_store.clear_failures(light)).to eql([failure])
    end

    it 'clears the failures' do
      failure = Stoplight::Failure.new('class', 'message', Time.new)
      data_store.record_failure(light, failure)
      data_store.clear_failures(light)
      expect(data_store.get_failures(light)).to eql([])
    end
  end

  describe '#get_state' do
    it 'is initially unlocked' do
      expect(data_store.get_state(light)).to eql(Stoplight::State::UNLOCKED)
    end
  end

  describe '#set_state' do
    it 'returns the state' do
      state = 'state'
      expect(data_store.set_state(light, state)).to eql(state)
    end

    it 'persists the state' do
      state = 'state'
      data_store.set_state(light, state)
      expect(data_store.get_state(light)).to eql(state)
    end
  end

  describe '#clear_state' do
    it 'returns the state' do
      state = 'state'
      data_store.set_state(light, state)
      expect(data_store.clear_state(light)).to eql(state)
    end

    it 'clears the state' do
      state = 'state'
      data_store.set_state(light, state)
      data_store.clear_state(light)
      expect(data_store.get_state(light)).to eql(Stoplight::State::UNLOCKED)
    end
  end
end
