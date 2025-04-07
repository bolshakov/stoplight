# frozen_string_literal: true

RSpec.shared_examples 'Stoplight::Light::Runnable#state' do
  let(:name) { random_string }

  it 'is initially unlocked' do
    expect(light.state).to eql(Stoplight::State::UNLOCKED)
  end

  context 'when its locked green' do
    before do
      data_store.set_state(config, Stoplight::State::LOCKED_GREEN)
    end

    it 'is locked green' do
      expect(light.state).to eql(Stoplight::State::LOCKED_GREEN)
    end
  end

  context 'when its locked red' do
    before do
      data_store.set_state(config, Stoplight::State::LOCKED_RED)
    end

    it 'is locked red' do
      expect(light.state).to eql(Stoplight::State::LOCKED_RED)
    end
  end
end
