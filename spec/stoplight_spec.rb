# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Stoplight do
  it 'is a module' do
    expect(described_class).to be_a(Module)
  end
end

RSpec.describe 'Stoplight' do
  subject(:light) { Stoplight(name, &code) }
  let(:name) { ('a'..'z').to_a.shuffle.join }
  let(:code) { -> {} }

  it 'creates a stoplight' do
    expect(light).to be_a(Stoplight::Light)
    expect(light.name).to eql(name)
  end
end
