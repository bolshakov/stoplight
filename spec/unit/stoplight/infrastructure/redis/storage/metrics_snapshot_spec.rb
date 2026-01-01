# frozen_string_literal: true

RSpec.describe Stoplight::Infrastructure::Redis::Storage::Metrics do
  let(:metrics) { described_class.new }

  let(:timestamp) { Time.now.to_f }
  let(:serialized_failure) { %({"error":{"class":"KeyError","message":"key not found"},"time":#{timestamp}}) }

  describe "#serialize_exception" do
    subject(:json) { metrics.serialize_exception(exception, timestamp:) }

    let(:exception) { KeyError.new("key not found") }

    it "serializes the exception" do
      expect(json).to eq(serialized_failure)
    end
  end

  describe "#deserialize_failure" do
    subject(:failure) { metrics.deserialize_failure(failure_json) }

    context "when nil" do
      let(:failure_json) { nil }

      it { is_expected.to be_nil }
    end

    context "not nil" do
      let(:failure_json) { serialized_failure }

      it "returns Failure object" do
        expect(failure).to eq(
          Stoplight::Domain::Failure.new("KeyError", "key not found", Time.at(timestamp))
        )
      end
    end
  end
end
