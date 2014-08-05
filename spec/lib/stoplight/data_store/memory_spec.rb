# coding: utf-8

require 'spec_helper'

describe Stoplight::DataStore::Memory do
  subject(:data_store) { described_class.new }

  describe '#read' do
    let(:key) { SecureRandom.hex }

    subject(:result) { data_store.read(key) }

    context 'without value' do
      it 'returns nil' do
        expect(result).to be_nil
      end
    end

    context 'with value' do
      let(:value) { double }

      before { data_store.write(key, value) }

      it 'returns the value' do
        expect(result).to eql(value)
      end
    end
  end

  describe '#write' do
    let(:key) { SecureRandom.hex }
    let(:value) { SecureRandom.hex }

    subject(:result) { data_store.write(key, value) }

    it 'returns the value' do
      expect(result).to eql(value)
    end
  end
end
