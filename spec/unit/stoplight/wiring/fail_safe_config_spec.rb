# frozen_string_literal: true

RSpec.describe Stoplight::Wiring::FailSafeConfig do
  it "has no notifiers" do
    expect(described_class.notifiers).to be_empty
  end

  it "uses Memory data store" do
    expect(described_class.data_store).to be_a(Stoplight::DataStore::Memory)
  end
end
