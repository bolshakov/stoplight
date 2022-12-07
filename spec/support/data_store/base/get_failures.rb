# frozen_string_literal: true

RSpec.shared_examples 'Stoplight::DataStore::Base#get_failures' do
  it 'is initially empty' do
    expect(data_store.get_failures(light)).to eql([])
  end

  it 'handles invalid JSON' do
    expect { data_store.record_failure(light, failure) }
      .to change { data_store.get_failures(light) }
      .from(be_empty)
      .to(contain_exactly(failure))
  end
end
