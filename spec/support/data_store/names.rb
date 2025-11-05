# frozen_string_literal: true

RSpec.shared_examples "Stoplight::Domain::DataStore#names" do
  let(:exception) { StandardError.new("Test error") }

  it "is initially empty" do
    expect(data_store.names).to eql([])
  end

  it "contains the name of a light with a failure" do
    data_store.record_failure(config, exception)
    expect(data_store.names).to eql([config.name])
  end

  it "contains the name of a light with a set state" do
    data_store.set_state(config, Stoplight::State::UNLOCKED)
    expect(data_store.names).to eql([config.name])
  end

  it "does not duplicate names" do
    data_store.record_failure(config, exception)
    data_store.set_state(config, Stoplight::State::UNLOCKED)
    expect(data_store.names).to eql([config.name])
  end

  it "supports names containing colons" do
    Stoplight("http://api.example.com/some/action")
    data_store.record_failure(config, exception)
    expect(data_store.names).to eql([config.name])
  end
end
