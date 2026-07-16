# frozen_string_literal: true

RSpec.describe Stoplight::Wiring::System::Storage do
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

  describe "#lock" do
    it "locks the light to the given color" do
      config = Stoplight::Wiring::DefaultConfig.with(name: "stripe")

      expect do
        storage.lock(config, Stoplight::Color::RED)
      end.to change { storage.state_snapshot(config).locked_state }
        .from(Stoplight::State::UNLOCKED)
        .to(Stoplight::State::LOCKED_RED)
    end
  end

  describe "#unlock" do
    it "unlocks the light" do
      config = Stoplight::Wiring::DefaultConfig.with(name: "stripe")
      storage.lock(config, Stoplight::Color::RED)

      expect do
        storage.unlock(config)
      end.to change { storage.state_snapshot(config).locked_state }
        .from(Stoplight::State::LOCKED_RED)
        .to(Stoplight::State::UNLOCKED)
    end
  end
end
