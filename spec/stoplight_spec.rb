# coding: utf-8

require 'spec_helper'

describe Stoplight do
  let(:name) { SecureRandom.hex }

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
        described_class.data_store = data_store
      end

      after { described_class.data_store = @data_store }

      it 'returns the data store' do
        expect(result).to eql(data_store)
      end
    end
  end

  describe '.notifiers' do
    subject(:result) { described_class.notifiers }

    it 'uses the default notifier' do
      expect(result).to be_an(Array)
      expect(result.size).to eql(1)
      expect(result.first).to be_a(Stoplight::Notifier::StandardError)
    end

    it 'memoizes the result' do
      expect(result).to be described_class.notifiers
    end

    context 'with custom notifiers' do
      let(:notifiers) { [notifier] }
      let(:notifier) { double }

      before do
        @notifiers = described_class.notifiers
        described_class.notifiers = notifiers
      end

      after { described_class.notifiers = @notifiers }

      it 'returns the notifiers' do
        expect(result).to eql(notifiers)
      end
    end
  end
end
