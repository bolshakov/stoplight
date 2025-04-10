# frozen_string_literal: true

require "spec_helper"

RSpec.describe Stoplight::VERSION do
  it "is a gem version" do
    expect(described_class).to be_a(Gem::Version)
  end
end
