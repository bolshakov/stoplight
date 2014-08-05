# coding: utf-8

require 'spec_helper'

describe Stoplight::Error do
  describe '::Base' do
    subject(:result) { described_class.const_get(:Base) }

    it 'subclasses StandardError' do
      expect(result).to be < StandardError
    end
  end

  describe '::NoCode' do
    subject(:result) { described_class.const_get(:NoCode) }

    it 'subclasses Base' do
      expect(result).to be < described_class.const_get(:Base)
    end
  end

  describe '::NoFallback' do
    subject(:result) { described_class.const_get(:NoFallback) }

    it 'subclasses Base' do
      expect(result).to be < described_class.const_get(:Base)
    end
  end
end
