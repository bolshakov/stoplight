# frozen_string_literal: true

RSpec.describe Stoplight::Wiring::System::Storage, :redis do
  let(:system) { Stoplight.__stoplight__system(SecureRandom.uuid.to_sym) }

  subject(:storage) { system.__stoplight__storage }

  describe "#state_snapshot" do
    it "returns default state for a light with no history" do
      snapshot = storage.state_snapshot(Stoplight::Wiring::DefaultConfig.with(name: "stripe"))

      expect(snapshot.color).to eq(Stoplight::Color::GREEN)
      expect(snapshot.locked_state).to eq(Stoplight::State::UNLOCKED)
    end
  end

  describe "#metrics_snapshot" do
    it "returns empty metrics for a light with no history" do
      snapshot = storage.metrics_snapshot(Stoplight::Wiring::DefaultConfig.with(name: "stripe"))

      expect(snapshot.consecutive_errors).to eq(0)
      expect(snapshot.last_error).to be_nil
    end
  end
end
