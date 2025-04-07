# frozen_string_literal: true

RSpec.shared_examples 'Stoplight::DataStore::Base#get_state' do
  it 'is initially unlocked' do
    expect(data_store.get_state(config)).to eql(Stoplight::State::UNLOCKED)
  end
end
