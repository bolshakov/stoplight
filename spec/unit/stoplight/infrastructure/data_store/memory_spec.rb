# frozen_string_literal: true

require_relative "recovery_metrics"
require_relative "metrics"

RSpec.describe Stoplight::Infrastructure::DataStore::Memory do
  let(:data_store) { described_class.new }
  let(:config) { Stoplight::Domain::Config.empty.with(name:, window_size:, cool_off_time:) }
  let(:name) { ("a".."z").to_a.shuffle.join }
  let(:cool_off_time) { 60 }
  let(:window_size) { 60 }

  it_behaves_like "Stoplight::Domain::DataStore"
  it_behaves_like "Stoplight::Domain::DataStore#get_metrics"
  it_behaves_like "Stoplight::Domain::DataStore#get_recovery_metrics"
  it_behaves_like "Stoplight::Domain::DataStore#names"
  it_behaves_like "Stoplight::Domain::DataStore#set_state"
  it_behaves_like "Stoplight::Domain::DataStore#transition_to_color"
end
