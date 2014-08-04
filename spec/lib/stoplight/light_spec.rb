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
end
