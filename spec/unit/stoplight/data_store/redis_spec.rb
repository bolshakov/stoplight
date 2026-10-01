# frozen_string_literal: true

RSpec.describe Stoplight::DataStore::Redis do
  subject(:data_store) { described_class.new(redis) }

  let(:redis) { instance_double(Redis) }

  describe "#__stoplight__scripting" do
    it "returns the same scripting cache instance on every call" do
      first_call = data_store.__stoplight__scripting

      expect(data_store.__stoplight__scripting).to be(first_call)
    end

    it "returns different scripting cache instance for different data stores" do
      other = described_class.new(redis)

      expect(data_store.__stoplight__scripting).not_to equal(other.__stoplight__scripting)
    end
  end
end
