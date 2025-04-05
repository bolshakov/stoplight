# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Stoplight do
  it 'is a module' do
    expect(described_class).to be_a(Module)
  end

  describe '.default_notifiers' do
    it 'is initially the default' do
      expect(described_class.default_notifiers)
        .to eql(Stoplight::Default::NOTIFIERS)
    end
  end

  describe '.default_data_store' do
    it 'is initially the default' do
      expect(described_class.default_data_store)
        .to eql(Stoplight::Default::DATA_STORE)
    end
  end

  describe '.default_error_notifier' do
    it 'is initially the default' do
      expect(described_class.default_error_notifier)
        .to eql(Stoplight::Default::ERROR_NOTIFIER)
    end
  end
end

RSpec.describe 'Stoplight' do
  subject(:light) { Stoplight(name) }

  let(:name) { ('a'..'z').to_a.shuffle.join }

  it 'creates a stoplight' do
    expect(light).to eq(Stoplight::Builder.with(name: name))
  end

  it 'is a class' do
    expect(light).to be_kind_of(Stoplight::CircuitBreaker)
  end

  describe '#name' do
    it 'reads the name' do
      expect(light.name).to eql(name)
    end
  end

  describe '#error_handler' do
    it 'it initially the default' do
      expect(light.error_handler).to eql(Stoplight::Default::ERROR_HANDLER)
    end
  end

  describe '#with_error_handler' do
    it 'sets the error handler' do
      error_handler = ->(_, _) {}
      with_error_handler = light.with_error_handler(&error_handler)
      expect(with_error_handler.error_handler).to eql(error_handler)
    end
  end
end
