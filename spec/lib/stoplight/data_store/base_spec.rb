# coding: utf-8

require 'spec_helper'

describe Stoplight::DataStore::Base do
  subject(:data_store) { described_class.new }

  describe '#read' do
    let(:key) { SecureRandom.hex }

    subject(:result) { data_store.read(key) }

    it 'raises an error' do
      expect { result }.to raise_error(NotImplementedError)
    end
  end

  describe '#write' do
    let(:key) { SecureRandom.hex }
    let(:value) { double }

    subject(:result) { data_store.write(key, value) }

    it 'raises an error' do
      expect { result }.to raise_error(NotImplementedError)
    end
  end
end
