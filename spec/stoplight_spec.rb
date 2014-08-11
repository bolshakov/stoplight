# coding: utf-8

require 'spec_helper'

describe Stoplight do
  let(:name) { SecureRandom.hex }

  it 'forwards all data store methods' do
    (Stoplight::DataStore::Base.new.methods - Object.methods).each do |method|
      expect(Stoplight).to respond_to(method)
    end
  end

  describe '::VERSION' do
    subject(:result) { described_class.const_get(:VERSION) }

    it 'is a Gem::Version' do
      expect(result).to be_a(Gem::Version)
    end
  end

  describe '.data_store' do
    subject(:result) { described_class.data_store }

    it 'uses the default data store' do
      expect(result).to be_a(Stoplight::DataStore::Memory)
    end

    it 'memoizes the result' do
      expect(result).to be described_class.data_store
    end

    context 'with a custom data store' do
      let(:data_store) { double }

      before do
        @data_store = described_class.data_store
        described_class.data_store(data_store)
      end

      after { described_class.data_store(@data_store) }

      it 'returns the data store' do
        expect(result).to eql(data_store)
      end
    end
  end

  describe '.green?' do
    subject(:result) { described_class.green?(name) }

    it 'is true' do
      expect(result).to be true
    end

    context 'locked green' do
      before do
        described_class.set_state(
          name, Stoplight::DataStore::STATE_LOCKED_GREEN)
      end

      it 'is true' do
        expect(result).to be true
      end
    end

    context 'locked red' do
      before do
        described_class.set_state(
          name, Stoplight::DataStore::STATE_LOCKED_RED)
      end

      it 'is false' do
        expect(result).to be false
      end
    end

    context 'with failures' do
      before do
        described_class.threshold(name).times do
          described_class.record_failure(name, nil)
        end
      end

      it 'is false' do
        expect(result).to be false
      end
    end
  end

  describe '.red?' do
    subject(:result) { described_class.red?(name) }

    context 'green' do
      before { allow(described_class).to receive(:green?).and_return(true) }

      it 'is false' do
        expect(result).to be false
      end
    end

    context 'not green' do
      before { allow(described_class).to receive(:green?).and_return(false) }

      it 'is true' do
        expect(result).to be true
      end
    end
  end

  describe '.threshold' do
    subject(:result) { described_class.threshold(name) }

    it 'uses the default threshold' do
      expect(result).to eql(Stoplight::Light::DEFAULT_THRESHOLD)
    end

    context 'with a custom threshold' do
      let(:threshold) { rand(10) }

      before { described_class.set_threshold(name, threshold) }

      it 'uses the threshold' do
        expect(result).to eql(threshold)
      end
    end
  end
end
