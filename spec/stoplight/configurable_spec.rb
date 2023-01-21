# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Stoplight::Configurable do
  describe '#with' do
    subject(:configurable) { configurable_class.new }

    let(:configurable_class) do
      Class.new do
        include Stoplight::Configurable

        def configuration
          Stoplight::Configuration.new(name: 'foo')
        end
      end
    end

    it 'raises NotImplementedError' do
      expect do
        configurable.with_data_store(nil)
      end.to raise_error(NotImplementedError)
    end
  end
end
