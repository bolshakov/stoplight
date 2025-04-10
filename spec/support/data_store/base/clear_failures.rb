# frozen_string_literal: true

RSpec.shared_examples "Stoplight::DataStore::Base#clear_failures" do
  before do
    data_store.record_failure(config, failure)
  end

  it "returns the failures" do
    expect(data_store.clear_failures(config)).to contain_exactly(failure)
  end

  it "returns an empty array when there are no failures" do
    data_store.clear_failures(config)

    expect(data_store.clear_failures(config)).to be_empty
  end

  it "clears the failures" do
    expect do
      data_store.clear_failures(config)
    end.to change { data_store.get_failures(config) }
      .from([failure]).to(be_empty)
  end
end
