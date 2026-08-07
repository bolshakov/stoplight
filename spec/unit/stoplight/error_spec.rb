# frozen_string_literal: true

RSpec.describe Stoplight::Error do
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
    let(:light_name) { "holy_light" }
    let(:cool_off_time) { 60 }
    let(:retry_after) { Time.now + 60 }

    it "is a class" do
      expect(described_class::RedLight).to be_a(Class)
    end

    it "is a subclass of StandardError" do
      expect(described_class::RedLight).to be < described_class::Base
    end

    it "record correct exception message with a light name" do
      error = described_class::RedLight.new(light_name, cool_off_time:, retry_after:)

      expect(error.message).to eq("Stoplight \"#{light_name}\" is red - traffic stopped until recovery.")
    end

    it "exposes the error metadata" do
      error = described_class::RedLight.new(light_name, cool_off_time:, retry_after:)

      expect(error).to have_attributes(light_name:, cool_off_time:, retry_after:)
    end
  end
end
