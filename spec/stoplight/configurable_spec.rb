# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Stoplight::Configurable do
  describe '#with' do
    subject(:configurable) { configurable_class.new }

    let(:configurable_class) do
      Class.new do
        include Stoplight::Configurable
      end
    end

    it 'raises NotImplementedError' do
      expect do
        configurable.with(configuration: nil)
      end.to raise_error(NotImplementedError)
    end
  end
end
