# frozen_string_literal: true

RSpec.shared_examples 'Stoplight::DataStore::Base#names' do
  it 'is initially empty' do
    expect(data_store.names).to eql([])
  end

  it 'contains a recently used light' do
    data_store.set_last_used_at(light, Time.now)

    expect(data_store.names).to eql([light.name])
  end

  it 'ignores light used long time ago' do
    usage_time = Time.now - 100
    data_store.set_last_used_at(light, usage_time)

    expect(data_store.names(used_after: usage_time + 1)).to be_empty
  end

  it 'supports names containing colons' do
    light = Stoplight::Light.new('http://api.example.com/some/action')
    data_store.set_last_used_at(light, Time.now)

    expect(data_store.names).to eql([light.name])
  end
end
