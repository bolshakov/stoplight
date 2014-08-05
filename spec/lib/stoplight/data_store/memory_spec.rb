# coding: utf-8

require 'spec_helper'

describe Stoplight::DataStore::Memory do
  subject(:data_store) { described_class.new }

  describe '#[]' do
    let(:key) { SecureRandom.hex }

    subject(:result) { data_store[key] }

    context 'without a value' do
      it 'returns nil' do
        expect(result).to be_nil
      end
    end

    context 'with a value' do
      let(:value) { double }

      before { data_store[key] = value }

      it 'returns the value' do
        expect(result).to eql(value)
      end
    end
  end

  describe '#[]=' do
    let(:key) { SecureRandom.hex }
    let(:value) { SecureRandom.hex }

    subject(:result) { data_store[key] = value }

    it 'returns the value' do
      expect(result).to eql(value)
    end
  end
end
