# coding: utf-8

require 'spec_helper'

describe Stoplight::Mixin do
  subject(:klass) { Class.new.extend(described_class) }

  describe '#stoplight' do
    subject(:result) { klass.stoplight(name, &code) }
    let(:name) { SecureRandom.hex }
    let(:code) { proc { code_result } }
    let(:code_result) { double }

    let(:light) { double }

    before do
      allow(Stoplight::Light).to receive(:new).and_return(light)
      allow(light).to receive(:run).and_return(code.call)
    end

    it 'calls .new' do
      expect(Stoplight::Light).to receive(:new)
      result
    end

    it 'calls #run' do
      expect(light).to receive(:run)
      result
    end

    it 'returns the result of #run' do
      expect(result).to eql(code_result)
    end
  end
end
