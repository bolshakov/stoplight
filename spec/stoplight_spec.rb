# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Stoplight do
  it 'is a module' do
    expect(described_class).to be_a(Module)
  end
end

RSpec.describe 'Stoplight' do
  subject(:light) { Stoplight(name) }

  let(:name) { ('a'..'z').to_a.shuffle.join }

  it 'creates a stoplight' do
    expect(light).to eq(Stoplight::Builder.with(name: name))
  end
end
