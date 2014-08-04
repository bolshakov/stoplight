# coding: utf-8

require 'spec_helper'

describe Stoplight::Errors do
  describe '::Base' do
    subject(:result) { described_class.const_get(:Base) }

    it 'subclasses StandardError' do
      expect(result).to be < StandardError
    end
  end
end
