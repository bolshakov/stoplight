# frozen_string_literal: true

RSpec.shared_examples 'Stoplight::Light::Runnable#color' do
  it 'is initially green' do
    expect(light.color).to eql(Stoplight::Color::GREEN)
  end

  context 'when its locked green' do
    before do
      light.data_store.set_state(light, Stoplight::State::LOCKED_GREEN)
    end

    it 'is green' do
      expect(light.color).to eql(Stoplight::Color::GREEN)
    end
  end

  context 'when its locked red' do
    before do
      light.data_store.set_state(light, Stoplight::State::LOCKED_RED)
    end

    it 'is red' do
      expect(light.color).to eql(Stoplight::Color::RED)
    end
  end

  context 'when there are many failures' do
    it 'turns red' do
      expect do
        light.threshold.times do
          light.data_store.record_failure(light, failure)
        end
      end.to change(light, :color).to be(Stoplight::Color::RED)
    end
  end

  context 'when the most recent failure is old' do
    let(:other) do
      Stoplight::Failure.new(
        error.class.name, error.message, Time.new - light.cool_off_time
      )
    end

    before do
      (light.threshold - 1).times do
        light.data_store.record_failure(light, failure)
      end
    end

    it 'turns yellow' do
      expect do
        light.data_store.record_failure(light, other)
      end.to change(light, :color).to be(Stoplight::Color::YELLOW)
    end
  end

  context 'when the least recent failure is old' do
    let(:other) do
      Stoplight::Failure.new(error.class.name, error.message, Time.new - light.cool_off_time)
    end

    before do
      light.data_store.record_failure(light, other)
    end

    it 'is red when the least recent failure is old' do
      expect do
        (light.threshold - 1).times do
          light.data_store.record_failure(light, failure)
        end
      end.to change(light, :color).to be(Stoplight::Color::RED)
    end
  end
end
