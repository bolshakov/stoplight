# frozen_string_literal: true

RSpec.shared_examples 'Stoplight::DataStore::Base#clear_failures' do
  before do
    data_store.record_failure(light, failure)
  end

  it 'returns the failures' do
    expect(data_store.clear_failures(light)).to contain_exactly(failure)
  end

  it 'clears the failures' do
    expect do
      data_store.clear_failures(light)
    end.to change { data_store.get_failures(light) }
      .from([failure]).to(be_empty)
  end
end
