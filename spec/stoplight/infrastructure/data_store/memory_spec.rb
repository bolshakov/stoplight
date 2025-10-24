# frozen_string_literal: true

RSpec.describe Stoplight::Infrastructure::DataStore::Memory do
  let(:data_store) { described_class.new }
  let(:config) { Stoplight::Domain::Config.empty.with(name:, window_size:, cool_off_time: 60) }
  let(:name) { ("a".."z").to_a.shuffle.join }
  let(:failure) { Stoplight::Domain::Failure.new("class", "message", Time.new - 1) }
  let(:other) { Stoplight::Domain::Failure.new("class", "message 2", Time.new) }
  let(:window_size) { Stoplight::Wiring::Default::WINDOW_SIZE }

  it_behaves_like "data store metrics"
  it_behaves_like "Stoplight::Domain::DataStore"
  it_behaves_like "Stoplight::Domain::DataStore#names"
  it_behaves_like "Stoplight::Domain::DataStore#set_state"
  it_behaves_like "Stoplight::Domain::DataStore#transition_to_color"
end
