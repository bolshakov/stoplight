# frozen_string_literal: true

RSpec.shared_examples 'Stoplight::DataStore::Base#clear_state' do
  let(:state) { 'state' }

  it 'returns the state' do
    data_store.set_state(light, state)

    expect(data_store.clear_state(light)).to eql(state)
  end

  it 'clears the state' do
    data_store.set_state(light, state)

    expect do
      data_store.clear_state(light)
    end.to change { data_store.get_state(light) }
      .from(state).to(Stoplight::State::UNLOCKED)
  end
end
