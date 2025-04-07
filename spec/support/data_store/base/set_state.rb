# frozen_string_literal: true

RSpec.shared_examples 'Stoplight::DataStore::Base#set_state' do
  let(:state) { 'state' }

  it 'returns the state' do
    expect(data_store.set_state(config, state)).to eql(state)
  end

  it 'persists the state' do
    data_store.set_state(config, state)

    expect(data_store.get_state(config)).to eql(state)
  end
end
