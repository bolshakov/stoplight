require 'spec_helper'

RSpec.describe Stoplight::DataStore::Test do
  let(:data_store) { described_class.new }
  let(:light) { Stoplight::Light.new(name) {} }
  let(:name) { ('a'..'z').to_a.shuffle.join }
  let(:failure) { Stoplight::Failure.new('class', 'message', Time.new) }

  it 'is a class' do
    expect(described_class).to be_a(Class)
  end

  it 'is a subclass of Memory' do
    expect(described_class).to be < Stoplight::DataStore::Memory
  end

  describe '#names' do
    it 'is initially empty' do
      expect(data_store.names).to eql([])
    end

    it 'contains the name of a light with a failure' do
      data_store.record_failure(light, failure)
      expect(data_store.names).to eql([light.name])
    end

    it 'contains the name of a light with a set state' do
      data_store.set_state(light, Stoplight::State::UNLOCKED)
      expect(data_store.names).to eql([light.name])
    end

    it 'does not duplicate names' do
      data_store.record_failure(light, failure)
      data_store.set_state(light, Stoplight::State::UNLOCKED)
      expect(data_store.names).to eql([light.name])
    end
  end

  describe '#get_all' do
    it 'returns the failures and the state' do
      failures, state = data_store.get_all(light)
      expect(failures).to eql([])
      expect(state).to eql(Stoplight::State::LOCKED_GREEN)
    end
  end

  describe '#get_failures' do
    it 'is initially empty' do
      expect(data_store.get_failures(light)).to eql([])
    end
  end

  describe '#record_failure' do
    it 'returns the number of failures' do
      expect(data_store.record_failure(light, failure)).to eql(1)
    end

    it 'persists the failure' do
      data_store.record_failure(light, failure)
      expect(data_store.get_failures(light)).to eql([failure])
    end

    it 'stores more recent failures at the front' do
      data_store.record_failure(light, failure)
      other = Stoplight::Failure.new('class', 'message 2', Time.new)
      data_store.record_failure(light, other)
      expect(data_store.get_failures(light)).to eql([other, failure])
    end

    it 'limits the number of stored failures' do
      light.with_threshold(1)
      data_store.record_failure(light, failure)
      other = Stoplight::Failure.new('class', 'message 2', Time.new)
      data_store.record_failure(light, other)
      expect(data_store.get_failures(light)).to eql([other])
    end
  end

  describe '#clear_failures' do
    it 'returns the failures' do
      data_store.record_failure(light, failure)
      expect(data_store.clear_failures(light)).to eql([failure])
    end

    it 'clears the failures' do
      data_store.record_failure(light, failure)
      data_store.clear_failures(light)
      expect(data_store.get_failures(light)).to eql([])
    end
  end

  describe '#get_state' do
    it 'is always green' do
      expect(data_store.get_state(light)).to eql(Stoplight::State::LOCKED_GREEN)
    end
  end

  describe '#set_state' do
    it 'returns the state' do
      state = 'state'
      expect(data_store.set_state(light, state)).to eql(state)
    end

    it 'does not persist the state' do
      state = 'state'
      data_store.set_state(light, state)
      expect(data_store.get_state(light)).to eql(Stoplight::State::LOCKED_GREEN)
    end
  end

  describe '#clear_state' do
    it 'returns the locked green' do
      state = 'state'
      data_store.set_state(light, state)
      expect(data_store.clear_state(light)).to eql(Stoplight::State::LOCKED_GREEN)
    end

    it 'returns green state' do
      state = 'state'
      data_store.set_state(light, state)
      data_store.clear_state(light)
      expect(data_store.get_state(light)).to eql(Stoplight::State::LOCKED_GREEN)
    end
  end
end
