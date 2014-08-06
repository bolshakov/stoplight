# coding: utf-8

require 'spec_helper'

describe Stoplight do
  describe '::VERSION' do
    subject(:result) { described_class.const_get(:VERSION) }

    it 'is a Gem::Version' do
      expect(result).to be_a(Gem::Version)
    end
  end
end
