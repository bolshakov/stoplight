# coding: utf-8

require 'spec_helper'
require 'fakeredis'

describe Stoplight::DataStore::Redis do
  let(:error) { error_class.new }
  let(:error_class) { Class.new(StandardError) }
  let(:name) { SecureRandom.hex }
  let(:state) { Stoplight::DataStore::STATES.to_a.sample }
  let(:threshold) { rand(10) }

  subject(:data_store) { described_class.new }

  it_behaves_like 'a data store'

  describe '#attempts' do
    subject(:result) { data_store.attempts(name) }

    it 'returns 0' do
      expect(result).to eql(0)
    end

    context 'with an attempt' do
      before { data_store.record_attempt(name) }

      it 'returns 1' do
        expect(result).to eql(1)
      end
    end
  end

  describe '#clear_attempts' do
    subject(:result) { data_store.clear_attempts(name) }

    it 'returns 0' do
      expect(result).to eql(0)
    end

    context 'with an attempt' do
      before { data_store.record_attempt(name) }

      it 'returns 1' do
        expect(result).to eql(1)
      end

      it 'clears the attempts' do
        result
        expect(data_store.attempts(name)).to eql(0)
      end
    end
  end

  describe '#clear_failures' do
    subject(:result) { data_store.clear_failures(name) }

    it 'returns 0' do
      expect(result).to eql(0)
    end

    context 'with a failure' do
      before { data_store.record_failure(name, error) }

      it 'returns 1' do
        expect(result).to eql(1)
      end

      it 'clears the failures' do
        result
        expect(data_store.failures(name)).to be_empty
      end
    end
  end

  describe '#failures' do
    subject(:result) { data_store.failures(name) }

    it 'returns an empty array' do
      expect(result).to be_an(Array)
      expect(result).to be_empty
    end

    context 'with a failure' do
      before { data_store.record_failure(name, error) }

      it 'returns a non-empty array' do
        expect(result).to be_an(Array)
        expect(result).to_not be_empty
      end
    end
  end

  describe '#names' do
    subject(:result) { data_store.names }

    it 'returns an array' do
      expect(result).to be_an(Array)
    end

    context 'with a name' do
      before { data_store.set_threshold(name, threshold) }

      it 'includes the name' do
        expect(result).to include(name)
      end
    end
  end

  describe '#record_attempt' do
    subject(:result) { data_store.record_attempt(name) }

    it 'returns 1' do
      expect(result).to eql(1)
    end

    it 'records the attempt' do
      result
      expect(data_store.attempts(name)).to eql(1)
    end
  end

  describe '#record_failure' do
    subject(:result) { data_store.record_failure(name, error) }

    it 'returns 1' do
      expect(result).to eql(1)
    end

    it 'records the failure' do
      result
      expect(data_store.failures(name)).to_not be_empty
    end
  end

  describe '#set_state' do
    subject(:result) { data_store.set_state(name, state) }

    it 'returns the state' do
      expect(result).to eql(state)
    end

    it 'sets the state' do
      result
      expect(data_store.state(name)).to eql(state)
    end
  end

  describe '#set_threshold' do
    subject(:result) { data_store.set_threshold(name, threshold) }

    it 'returns the threshold' do
      expect(result).to eql(threshold)
    end

    it 'sets the threshold' do
      result
      expect(data_store.threshold(name)).to eql(threshold)
    end
  end

  describe '#state' do
    subject(:result) { data_store.state(name) }

    it 'returns the default state' do
      expect(result).to eql(Stoplight::DataStore::STATE_UNLOCKED)
    end

    context 'with a state' do
      before { data_store.set_state(name, state) }

      it 'returns the state' do
        expect(result).to eql(state)
      end
    end
  end

  describe '#threshold' do
    subject(:result) { data_store.threshold(name) }

    it 'returns nil' do
      expect(result).to be(nil)
    end

    context 'with a threshold' do
      before { data_store.set_threshold(name, threshold) }

      it 'returns the threshold' do
        expect(result).to eql(threshold)
      end
    end
  end
end
