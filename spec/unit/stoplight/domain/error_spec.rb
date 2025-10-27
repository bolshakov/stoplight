# frozen_string_literal: true

RSpec.describe Stoplight::Domain::Error do
  it "is a module" do
    expect(described_class).to be_a(Module)
  end

  describe "::Base" do
    it "is a class" do
      expect(described_class::Base).to be_a(Class)
    end

    it "is a subclass of StandardError" do
      expect(described_class::Base).to be < StandardError
    end
  end

  describe "::IncorrectColor" do
    it "is a class" do
      expect(described_class::IncorrectColor).to be_a(Class)
    end

    it "is a subclass of StandardError" do
      expect(described_class::IncorrectColor).to be < StandardError
    end
  end

  describe "::RedLight" do
    it "is a class" do
      expect(described_class::RedLight).to be_a(Class)
    end

    it "is a subclass of StandardError" do
      expect(described_class::RedLight).to be < described_class::Base
    end
  end
end
