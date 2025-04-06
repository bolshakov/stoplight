# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Stoplight::Light do
  let(:name) { ('a'..'z').to_a.shuffle.join }

  describe '.with' do
    context 'with only name' do
      subject(:config) { light.config }

      let(:light) { described_class.with(name: name) }

      it 'sets configuration to default values' do
        expect(config).to have_attributes(
          name: name,
          data_store: Stoplight.default_data_store,
          notifiers: Stoplight.default_notifiers,
          cool_off_time: Stoplight::Default::COOL_OFF_TIME,
          threshold: Stoplight::Default::THRESHOLD,
          window_size: Stoplight::Default::WINDOW_SIZE
        )
      end
    end

    context 'with configured parameters' do
      subject(:config) { light.config }

      let(:light) { described_class.with(**configured_parameters) }
      let(:configured_parameters) do
        {
          name: name,
          data_store: 42,
          notifiers: [43],
          cool_off_time: 44,
          threshold: 45,
          window_size: 46
        }
      end

      it 'sets configuration parameters' do
        expect(config).to have_attributes(**configured_parameters)
      end
    end
  end

  it_behaves_like Stoplight::CircuitBreaker do
    let(:light) { Stoplight(name) }
    let(:circuit_breaker) { described_class.new(config) }
  end
end
