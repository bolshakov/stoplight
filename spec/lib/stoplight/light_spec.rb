# coding: utf-8

require 'spec_helper'

describe Stoplight::Light do
  subject(:light) { described_class.new }

  describe '#with_code' do
    let(:block) { proc {} }

    subject(:result) { light.with_code(&block) }

    it 'returns self' do
      expect(result).to equal(light)
    end

    it 'assigns @code' do
      expect(result.instance_variable_get(:@code)).to eql(block)
    end
  end

  describe '#with_fallback' do
    let(:block) { proc {} }

    subject(:result) { light.with_fallback(&block) }

    it 'returns self' do
      expect(result).to equal(light)
    end

    it 'assigns @fallback' do
      expect(result.instance_variable_get(:@fallback)).to eql(block)
    end
  end

  describe '#code' do
    subject(:result) { light.code }

    context 'without code' do
      it 'raises an error' do
        expect { result }.to raise_error(NotImplementedError)
      end
    end

    context 'with code' do
      let(:block) { proc {} }

      before { light.with_code(&block) }

      it 'return the code' do
        expect(result).to eql(block)
      end
    end
  end
end
