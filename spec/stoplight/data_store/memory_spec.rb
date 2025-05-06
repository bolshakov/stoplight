# frozen_string_literal: true

require "spec_helper"

RSpec.describe Stoplight::DataStore::Memory do
  let(:data_store) { described_class.new }
  let(:config) { Stoplight.config_provider.provide(name) }
  let(:name) { ("a".."z").to_a.shuffle.join }
  let(:failure) { Stoplight::Failure.new("class", "message", Time.new - 1) }
  let(:other) { Stoplight::Failure.new("class", "message 2", Time.new) }

  it_behaves_like "data store metrics"
  it_behaves_like "Stoplight::DataStore::Base"
  it_behaves_like "Stoplight::DataStore::Base#names"
  it_behaves_like "Stoplight::DataStore::Base#get_state"
  it_behaves_like "Stoplight::DataStore::Base#set_state"
  it_behaves_like "Stoplight::DataStore::Base#clear_state"
  it_behaves_like "Stoplight::DataStore::Base#transition_to_color"
end
