# frozen_string_literal: true

RSpec.describe Stoplight::Wiring::LightConfigurationDsl do
  describe "#initialize" do
    context "when tracked_errors contains an anonymous class" do
      subject(:dsl) { described_class.new(name: "light", tracked_errors: [Class.new(StandardError)]) }

      it "raises ArgumentError" do
        expect { dsl }.to raise_error(ArgumentError)
      end
    end

    context "when tracked_errors contains an instance with a #name method" do
      subject(:dsl) { described_class.new(name: "light", tracked_errors: [Struct.new(:name).new("StandardError")]) }

      it "raises ArgumentError" do
        expect { dsl }.to raise_error(ArgumentError)
      end
    end

    context "when skipped_errors contains an anonymous class" do
      subject(:dsl) { described_class.new(name: "light", skipped_errors: [Class.new(StandardError)]) }

      it "raises ArgumentError" do
        expect { dsl }.to raise_error(ArgumentError)
      end
    end

    context "when skipped_errors contains an instance with a #name method" do
      subject(:dsl) { described_class.new(name: "light", skipped_errors: [Struct.new(:name).new("StandardError")]) }

      it "raises ArgumentError" do
        expect { dsl }.to raise_error(ArgumentError)
      end
    end
  end
end
