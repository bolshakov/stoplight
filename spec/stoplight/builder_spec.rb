# frozen_string_literal: true

require 'spec_helper'
require 'securerandom'

RSpec.describe Stoplight::Builder do
  let(:name) { SecureRandom.uuid }

  describe '.with' do
    context 'with only name' do
      subject(:configuration) { builder.configuration }

      let(:builder) { described_class.with(name: name) }

      it 'sets configuration to default values' do
        expect(configuration).to have_attributes(
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
      subject(:configuration) { builder.configuration }

      let(:builder) { described_class.with(**configured_parameters) }
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
        expect(configuration).to have_attributes(**configured_parameters)
      end
    end
  end

  describe '.build' do
    subject(:light) { builder.build }

    let(:builder) { described_class.new(configuration) }
    let(:configuration) { instance_double(Stoplight::Configuration, name: name) }

    it 'builds new light' do
      expect(light.configuration).to eq(configuration)
    end
  end

  context 'methods building an instance of light' do
    let(:builder) { described_class.new(configuration) }
    let(:configuration) do
      Stoplight::Configuration.new(
        name: name,
        data_store: Stoplight.default_data_store,
        notifiers: Stoplight.default_notifiers,
        cool_off_time: Stoplight::Default::COOL_OFF_TIME,
        threshold: Stoplight::Default::THRESHOLD,
        window_size: Stoplight::Default::WINDOW_SIZE,
        error_notifier: Stoplight.default_error_notifier
      )
    end

    describe '#run' do
      it 'yields the block' do
        expect do |code|
          builder.run(&code)
        end.to yield_control
      end
    end

    describe '#lock' do
      context 'when the light is not locked' do
        it 'locks the light' do
          expect { builder.lock(Stoplight::Color::RED) }
            .to change(builder, :color)
            .from(Stoplight::Color::GREEN)
            .to(Stoplight::Color::RED)
        end
      end

      context 'when the light is locked' do
        before do
          builder.lock(Stoplight::Color::RED)
        end

        it 'does not change the light' do
          expect { builder.lock(Stoplight::Color::RED) }
            .not_to change(builder, :color)
            .from(Stoplight::Color::RED)
        end
      end
    end

    describe '#unlock' do
      context 'when the light is not locked' do
        it 'does nothing' do
          expect { builder.unlock }
            .not_to change(builder, :color)
            .from(Stoplight::Color::GREEN)
        end
      end

      context 'when the light is locked' do
        before do
          builder.lock(Stoplight::Color::RED)
        end

        it 'unlocks the light' do
          expect { builder.unlock }
            .to change(builder, :color)
            .from(Stoplight::Color::RED)
            .to(Stoplight::Color::GREEN)
        end
      end
    end
  end

  it_behaves_like Stoplight::CircuitBreaker do
    let(:circuit_breaker) { described_class.new(configuration) }
  end
end
