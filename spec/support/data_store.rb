# frozen_string_literal: true

require_relative "data_store/names"
require_relative "data_store/set_state"
require_relative "data_store/metrics"
require_relative "data_store/transition_to_color"

RSpec.shared_examples "Stoplight::Domain::DataStore" do
  it "is a class" do
    expect(described_class).to be_a(Class)
  end

  it "is a subclass of Base" do
    expect(described_class).to be < Stoplight::Domain::DataStore
  end
end
