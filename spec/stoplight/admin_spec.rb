# frozen_string_literal: true

RSpec.describe Stoplight::Admin do
  context "smoke test" do
    it "registers itself as a sinatra module" do
      expect(described_class).to respond_to(:registered)
    end
  end
end
