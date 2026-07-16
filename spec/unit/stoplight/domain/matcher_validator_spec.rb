# frozen_string_literal: true

RSpec.describe Stoplight::Domain::MatcherValidator do
  subject(:validate) { described_class.call(matcher) }

  context "when the matcher is a named class" do
    let(:matcher) { StandardError }

    it "returns its name" do
      expect(validate).to eq("StandardError")
    end
  end

  context "when the matcher is a custom class overriding #===" do
    let(:matcher) do
      Class.new(StandardError) do
        def self.name = "CustomMatcher"

        def self.===(other) = other.is_a?(StandardError)
      end
    end

    it "returns its name" do
      expect(validate).to eq("CustomMatcher")
    end
  end

  context "when the matcher is a bare module" do
    let(:matcher) do
      Module.new do
        def self.name = "CustomModule"
      end
    end

    it "returns its name" do
      expect(validate).to eq("CustomModule")
    end
  end

  context "when the matcher does not respond to #name" do
    let(:matcher) { ->(error) { error.is_a?(StandardError) } }

    it "raises ArgumentError naming the offending value" do
      expect { validate }.to raise_error(ArgumentError, a_string_matching(/#{Regexp.escape(matcher.inspect)}/))
    end
  end

  context "when the matcher is an instance with a #name method" do
    let(:matcher) { Struct.new(:name).new("StandardError") }

    it "raises ArgumentError naming the offending value" do
      expect { validate }.to raise_error(ArgumentError, a_string_matching(/#{Regexp.escape(matcher.inspect)}/))
    end
  end

  context "when the matcher is an anonymous class" do
    let(:matcher) { Class.new(StandardError) }

    it "raises ArgumentError naming the offending value" do
      expect { validate }.to raise_error(ArgumentError, a_string_matching(/#{Regexp.escape(matcher.inspect)}/))
    end
  end
end
