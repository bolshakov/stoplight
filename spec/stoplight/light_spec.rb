# coding: utf-8

require 'spec_helper'

describe Stoplight::Light do
  let(:name) { SecureRandom.hex }
  let(:code) { proc {} }

  subject(:light) { described_class.new(name, &code) }

  describe '.data_store' do
    let(:klass) { Class.new(described_class) }

    subject(:result) { klass.data_store }

    context 'without a data store' do
      it 'returns the default' do
        expect(result).to be_a(Stoplight::DataStore::Memory)
      end
    end

    context 'with a data store' do
      let(:data_store) { double }

      before { klass.data_store(data_store) }

      it 'returns the data store' do
        expect(result).to eql(data_store)
      end
    end
  end

  describe '#with_fallback' do
    let(:fallback) { proc {} }

    subject(:result) { light.with_fallback(&fallback) }

    it 'returns self' do
      expect(result).to equal(light)
    end

    it 'assigns @fallback' do
      expect(result.instance_variable_get(:@fallback)).to eql(fallback)
    end
  end

  describe '#code' do
    subject(:result) { light.code }

    it 'returns the code' do
      expect(result).to eql(code)
    end
  end

  describe '#fallback' do
    subject(:result) { light.fallback }

    context 'without a fallback' do
      it 'raises an error' do
        expect { result }.to raise_error(Stoplight::Error::NoFallback)
      end
    end

    context 'with a fallback' do
      let(:fallback) { proc {} }

      before { light.with_fallback(&fallback) }

      it 'returns the fallback' do
        expect(result).to eql(fallback)
      end
    end
  end

  describe '#name' do
    subject(:result) { light.name }

    it 'returns the name' do
      expect(result).to eql(name)
    end
  end

  describe '#run_code' do
    pending
  end

  describe '#run_fallback' do
    pending
  end
end
