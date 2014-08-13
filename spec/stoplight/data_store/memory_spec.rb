# coding: utf-8

require 'spec_helper'

describe Stoplight::DataStore::Memory do
  let(:error) { error_klass.new }
  let(:error_klass) { Class.new(StandardError) }
  let(:name) { SecureRandom.hex }
  let(:state) { Stoplight::DataStore::STATE_LOCKED_GREEN }
  let(:threshold) { rand(10) }

  subject(:data_store) { described_class.new }

  it_behaves_like 'a data store'

  describe '#attempts' do
    subject(:result) { data_store.attempts(name) }

    it 'is zero' do
      expect(result).to eql(0)
    end

    context 'with an attempt' do
      before { data_store.record_attempt(name) }

      it 'is one' do
        expect(result).to eql(1)
      end
    end
  end

  describe '#clear_attempts' do
    subject(:result) { data_store.clear_attempts(name) }

    it 'returns nil' do
      expect(result).to be_nil
    end

    context 'with an attempt' do
      before { data_store.record_attempt(name) }

      it 'returns one' do
        expect(result).to eql(1)
      end

      it 'clears attempts' do
        result
        expect(data_store.attempts(name)).to eql(0)
      end
    end
  end

  describe '#clear_failures' do
    subject(:result) { data_store.clear_failures(name) }

    it 'returns nil' do
      expect(result).to be nil
    end

    context 'with a failure' do
      before { data_store.record_failure(name, error) }

      it 'returns the failures' do
        failures = data_store.failures(name)
        expect(result).to eql(failures)
      end

      it 'clears the failures' do
        result
        expect(data_store.failures(name)).to be_empty
      end
    end
  end

  describe '#threshold' do
    subject(:result) { data_store.threshold(name) }

    it 'is nil' do
      expect(result).to be nil
    end

    context 'with a threshold' do
      before { data_store.set_threshold(name, threshold) }

      it 'returns the threshold' do
        expect(result).to eql(threshold)
      end
    end
  end

  describe '#failures' do
    subject(:result) { data_store.failures(name) }

    it 'is an array' do
      expect(result).to be_an(Array)
    end

    it 'is empty' do
      expect(result).to be_empty
    end

    context 'with a failure' do
      before { data_store.record_failure(name, error) }

      it 'returns the failures' do
        expect(result.size).to eql(1)
      end
    end
  end

  describe '#names' do
    subject(:result) { data_store.names }

    it 'is an array' do
      expect(result).to be_an(Array)
    end

    it 'is empty' do
      expect(result).to be_empty
    end

    context 'with a name' do
      before { data_store.settings(name) }

      it 'includes the name' do
        expect(result).to include(name)
      end
    end
  end

  describe '#record_attempt' do
    subject(:result) { data_store.record_attempt(name) }

    it 'records the attempt' do
      result
      expect(data_store.attempts(name)).to eql(1)
    end
  end

  describe '#record_failure' do
    subject(:result) { data_store.record_failure(name, error) }

    it 'returns the failures' do
      expect(result).to eql(data_store.failures(name))
    end

    it 'logs the failure' do
      expect(result.size).to eql(1)
    end
  end

  describe '#set_threshold' do
    subject(:result) { data_store.set_threshold(name, threshold) }

    it 'returns the threshold' do
      expect(result).to eql(threshold)
    end
  end

  describe '#set_state' do
    subject(:result) { data_store.set_state(name, state) }

    it 'returns the state' do
      expect(result).to eql(state)
    end

    context 'with an invalid state' do
      let(:state) { SecureRandom.hex }

      it 'raises an error' do
        expect { result }.to raise_error(ArgumentError)
      end
    end
  end

  describe '#state' do
    subject(:result) { data_store.state(name) }

    it 'returns the default state' do
      expect(result).to eql(Stoplight::DataStore::STATE_UNLOCKED)
    end

    context 'with a custom state' do
      before { data_store.set_state(name, state) }

      it 'returns the state' do
        expect(result).to eql(state)
      end
    end
  end
end
