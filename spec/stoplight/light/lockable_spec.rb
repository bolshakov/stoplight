# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Stoplight::Light::Lockable do
  subject(:light) { Stoplight::Light.new(config) }

  let(:config) { Stoplight::Config.new(name: name) }
  let(:code) { -> { code_result } }
  let(:code_result) { random_string }
  let(:name) { random_string }

  def random_string
    ('a'..'z').to_a.sample(8).join
  end

  describe '#lock' do
    let(:color) { Stoplight::Color::GREEN }

    context 'with correct color' do
      it 'returns the light' do
        expect(light.lock(color)).to be_a Stoplight::Light
      end

      context 'with green color' do
        let(:color) { Stoplight::Color::GREEN }

        it 'locks green color' do
          expect(config.data_store).to receive(:set_state).with(config, Stoplight::State::LOCKED_GREEN)

          light.lock(color)
        end
      end

      context 'with red color' do
        let(:color) { Stoplight::Color::RED }

        it 'locks red color' do
          expect(config.data_store).to receive(:set_state).with(config, Stoplight::State::LOCKED_RED)

          light.lock(color)
        end
      end
    end

    context 'with incorrect color' do
      let(:color) { 'incorrect-color' }

      it 'raises Error::IncorrectColor error' do
        expect { light.lock(color) }.to raise_error(Stoplight::Error::IncorrectColor)
      end

      it 'does not lock color' do
        expect(config.data_store).to_not receive(:set_state)

        suppress(Stoplight::Error::IncorrectColor) { light.lock(color) }
      end
    end
  end

  describe '#unlock' do
    it 'returns the light' do
      expect(light.unlock).to be_a Stoplight::Light
    end

    context 'with locked green light' do
      before { light.lock(Stoplight::Color::GREEN) }

      it 'unlocks light' do
        expect(config.data_store).to receive(:set_state).with(config, Stoplight::State::UNLOCKED)

        light.unlock
      end
    end

    context 'with locked red light' do
      before { light.lock(Stoplight::Color::RED) }

      it 'unlocks light' do
        expect(config.data_store).to receive(:set_state).with(config, Stoplight::State::UNLOCKED)

        light.unlock
      end
    end

    context 'with unlocked light' do
      it 'unlocks light' do
        expect(config.data_store).to receive(:set_state).with(config, Stoplight::State::UNLOCKED)

        light.unlock
      end
    end
  end
end
