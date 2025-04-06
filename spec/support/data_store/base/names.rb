# frozen_string_literal: true

RSpec.shared_examples 'Stoplight::DataStore::Base#names' do
  it 'is initially empty' do
    expect(data_store.names).to eql([])
  end

  it 'contains the name of a light with a failure' do
    data_store.record_failure(light, failure)
    expect(data_store.names).to eql([light.name])
  end

  it 'contains the name of a light with a set state' do
    data_store.set_state(light, Stoplight::State::UNLOCKED)
    expect(data_store.names).to eql([light.name])
  end

  it 'does not duplicate names' do
    data_store.record_failure(light, failure)
    data_store.set_state(light, Stoplight::State::UNLOCKED)
    expect(data_store.names).to eql([light.name])
  end

  it 'supports names containing colons' do
    light = Stoplight('http://api.example.com/some/action')
    data_store.record_failure(light, failure)
    expect(data_store.names).to eql([light.name])
  end
end
