# frozen_string_literal: true

require 'spec_helper'
require 'stringio'

RSpec.describe Stoplight::Light::Runnable, :redis do
  subject(:light) { Stoplight::Light.new(name, &code) }

  let(:code) { -> { code_result } }
  let(:code_result) { random_string }
  let(:fallback) { ->(_) { fallback_result } }
  let(:fallback_result) { random_string }
  let(:name) { random_string }

  let(:failure) do
    Stoplight::Failure.new(error.class.name, error.message, time)
  end
  let(:error) { error_class.new(error_message) }
  let(:error_class) { Class.new(StandardError) }
  let(:error_message) { random_string }
  let(:time) { Time.new }

  def random_string
    ('a'..'z').to_a.sample(8).join
  end

  before do
    light.with_data_store(data_store)
  end

  context 'with memory data store' do
    let(:data_store) { Stoplight::DataStore::Memory.new }

    it_behaves_like 'Stoplight::Light::Runnable#color'
    it_behaves_like 'Stoplight::Light::Runnable#run'
  end

  context 'with redis data store', :redis do
    let(:data_store) { Stoplight::DataStore::Redis.new(redis) }

    it_behaves_like 'Stoplight::Light::Runnable#color'
    it_behaves_like 'Stoplight::Light::Runnable#run'
  end

  describe '#lock' do
    context 'with correct color' do
      context 'with green color' do
        let(:color) { Stoplight::Color::GREEN }

        it 'locks green color' do
          expect(subject.data_store).to receive(:set_state).with(subject, Stoplight::State::LOCKED_GREEN)

          subject.lock(color)
        end
      end

      context 'with red color' do
        let(:color) { Stoplight::Color::RED }

        it 'locks red color' do
          expect(subject.data_store).to receive(:set_state).with(subject, Stoplight::State::LOCKED_RED)

          subject.lock(color)
        end
      end
    end

    context 'with incorrect color' do
      let(:color) { 'incorrect-color' }

      it 'raises Error::IncorrectColor error' do
        expect { subject.lock(color) }.to raise_error(Stoplight::Error::IncorrectColor)
      end

      it 'does not lock color' do
        expect(subject.data_store).to_not receive(:set_state)

        suppress(Stoplight::Error::IncorrectColor) { subject.lock(color) }
      end
    end
  end

  describe '#unlock' do
    context 'with locked green light' do
      before { subject.lock(Stoplight::Color::GREEN) }

      it 'unlocks light' do
        expect(subject.data_store).to receive(:set_state).with(subject, Stoplight::State::UNLOCKED)

        subject.unlock
      end
    end

    context 'with locked red light' do
      before { subject.lock(Stoplight::Color::RED) }

      it 'unlocks light' do
        expect(subject.data_store).to receive(:set_state).with(subject, Stoplight::State::UNLOCKED)

        subject.unlock
      end
    end

    context 'with unlocked light' do
      it 'unlocks light' do
        expect(subject.data_store).to receive(:set_state).with(subject, Stoplight::State::UNLOCKED)

        subject.unlock
      end
    end
  end
end
