# coding: utf-8

require 'spec_helper'

describe Stoplight::Failure do
  let(:error) { double }
  subject(:failure) { described_class.new(error) }

  describe '#initialize' do
    it 'assigns @time' do
      expect(failure.instance_variable_get(:@time)).to be_within(1).of(Time.now)
    end
  end

  describe '#time' do
    subject(:result) { failure.time }

    it 'returns the time' do
      expect(result).to be_within(1).of(Time.now)
    end
  end
end
