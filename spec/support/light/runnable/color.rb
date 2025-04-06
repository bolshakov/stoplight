# frozen_string_literal: true

RSpec.shared_examples 'Stoplight::Light::Runnable#color' do
  let(:name) { random_string }
  let(:config) { light.config }

  it { expect(config.data_store).to eq(data_store) }

  it 'is initially green' do
    expect(light.color).to eql(Stoplight::Color::GREEN)
  end

  context 'when its locked green' do
    before do
      data_store.set_state(config, Stoplight::State::LOCKED_GREEN)
    end

    it 'is green' do
      expect(light.color).to eql(Stoplight::Color::GREEN)
    end
  end

  context 'when its locked red' do
    before do
      data_store.set_state(config, Stoplight::State::LOCKED_RED)
    end

    it 'is red' do
      expect(light.color).to eql(Stoplight::Color::RED)
    end
  end

  context 'when there are many failures' do
    let(:anther) { Stoplight::Failure.new(error.class.name, error.message, time - 10) }
    let(:light) { super().with_threshold(2) }

    before do
      data_store.record_failure(config, failure)
    end

    it 'turns red' do
      expect do
        data_store.record_failure(config, anther)
      end.to change(light, :color).to be(Stoplight::Color::RED)
    end
  end

  context 'when the most recent failure is old' do
    let(:failure) { Stoplight::Failure.new(error.class.name, error.message, Time.new - config.cool_off_time) }
    let(:failure2) { Stoplight::Failure.new(error.class.name, error.message, Time.new - config.cool_off_time - 10) }
    let(:light) { super().with_threshold(2) }

    before do
      data_store.record_failure(config, failure2)
    end

    it 'turns yellow' do
      expect do
        data_store.record_failure(config, failure)
      end.to change(light, :color).to be(Stoplight::Color::YELLOW)
    end
  end

  context 'when the least recent failure is old' do
    let(:other) do
      Stoplight::Failure.new(error.class.name, error.message, Time.new - config.cool_off_time)
    end
    let(:light) { super().with_threshold(2) }

    before do
      data_store.record_failure(config, other)
    end

    it 'is red when the least recent failure is old' do
      expect do
        data_store.record_failure(config, failure)
      end.to change(light, :color).to be(Stoplight::Color::RED)
    end
  end
end
