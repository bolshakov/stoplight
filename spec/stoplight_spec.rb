# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Stoplight do
  it 'is a module' do
    expect(described_class).to be_a(Module)
  end
end

RSpec.describe 'Stoplight' do
  let(:name) { ('a'..'z').to_a.shuffle.join }

  context 'with code' do
    subject(:light) { Stoplight(name, &code) }
    let(:code) { -> {} }

    it 'creates a stoplight' do
      expect(light).to be_a(Stoplight::Light)
      expect(light.name).to eql(name)
      expect(light.code).to eql(code)
    end
  end

  context 'without code' do
    subject(:light) { Stoplight(name) }

    it 'creates a stoplight' do
      expect(light).to be_a(Stoplight::Light)
      expect(light.name).to eql(name)
      expect(light.code).to be_nil
    end
  end
end
