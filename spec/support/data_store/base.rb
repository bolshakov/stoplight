# frozen_string_literal: true

require_relative "base/names"
require_relative "base/set_state"
require_relative "base/clear_state"
require_relative "base/metrics"
require_relative "base/transition_to_color"

RSpec.shared_examples "Stoplight::DataStore::Base" do
  it "is a class" do
    expect(described_class).to be_a(Class)
  end

  it "is a subclass of Base" do
    expect(described_class).to be < Stoplight::DataStore::Base
  end
end
