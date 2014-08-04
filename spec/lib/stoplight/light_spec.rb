# coding: utf-8

require 'spec_helper'

describe Stoplight::Light do
  subject(:light) { described_class.new }

  describe '#with_code' do
    let(:code) { proc {} }

    subject(:result) { light.with_code(&code) }

    it 'returns self' do
      expect(result).to equal(light)
    end

    it 'assigns @code' do
      expect(result.instance_variable_get(:@code)).to eql(code)
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

  describe '#with_name' do
    let(:name) { SecureRandom.hex }

    subject(:result) { light.with_name(name) }

    it 'returns self' do
      expect(result).to equal(light)
    end

    it 'assigns @name' do
      expect(result.instance_variable_get(:@name)).to eql(name)
    end
  end

  describe '#code' do
    subject(:result) { light.code }

    context 'without code' do
      it 'raises an error' do
        expect { result }.to raise_error(Stoplight::Errors::NoCode)
      end
    end

    context 'with code' do
      let(:code) { proc {} }

      before { light.with_code(&code) }

      it 'return the code' do
        expect(result).to eql(code)
      end
    end
  end

  describe '#fallback' do
    subject(:result) { light.fallback }

    context 'without fallback' do
      it 'raises an error' do
        expect { result }.to raise_error(Stoplight::Errors::NoFallback)
      end
    end

    context 'with fallback' do
      let(:fallback) { proc {} }

      before { light.with_fallback(&fallback) }

      it 'return the fallback' do
        expect(result).to eql(fallback)
      end
    end
  end
end
