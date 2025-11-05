# frozen_string_literal: true

RSpec.describe Stoplight::Domain::Color do
  it "is a module" do
    expect(described_class).to be_a(Module)
  end

  describe "::GREEN" do
    it "is a string" do
      expect(described_class::GREEN).to be_a(String)
    end

    it "is frozen" do
      expect(described_class::GREEN).to be_frozen
    end
  end

  describe "::YELLOW" do
    it "is a string" do
      expect(described_class::YELLOW).to be_a(String)
    end

    it "is frozen" do
      expect(described_class::YELLOW).to be_frozen
    end
  end

  describe "::RED" do
    it "is a string" do
      expect(described_class::RED).to be_a(String)
    end

    it "is frozen" do
      expect(described_class::RED).to be_frozen
    end
  end
end
