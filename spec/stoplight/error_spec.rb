# frozen_string_literal: true

require "spec_helper"

RSpec.describe Stoplight::Error do
  it "is a module" do
    expect(described_class).to be_a(Module)
  end

  describe "::Base" do
    it "is a class" do
      expect(Stoplight::Error::Base).to be_a(Class)
    end

    it "is a subclass of StandardError" do
      expect(Stoplight::Error::Base).to be < StandardError
    end
  end

  describe "::IncorrectColor" do
    it "is a class" do
      expect(Stoplight::Error::IncorrectColor).to be_a(Class)
    end

    it "is a subclass of StandardError" do
      expect(Stoplight::Error::IncorrectColor).to be < StandardError
    end
  end

  describe "::RedLight" do
    it "is a class" do
      expect(Stoplight::Error::RedLight).to be_a(Class)
    end

    it "is a subclass of StandardError" do
      expect(Stoplight::Error::RedLight).to be < Stoplight::Error::Base
    end
  end
end
