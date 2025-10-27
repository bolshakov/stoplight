# frozen_string_literal: true

RSpec.describe Stoplight::Domain::Strategies::RedRunStrategy, :freeze do
  subject(:result) { strategy.execute(fallback, metadata:) { 42 } }

  let(:strategy) { described_class.new(config:, data_store:) }
  let(:config) { Stoplight::Domain::Config.empty.with(name: "foo") }
  let(:metadata) { instance_double(Stoplight::Domain::Metadata, recovery_scheduled_after: Time.now) }
  let(:data_store) { instance_double(Stoplight::Domain::DataStore) }

  context "when fallback is provided" do
    let(:fallback) {
      ->(error) {
        @error = error
        "Fallback"
      }
    }

    it "returns fallback" do
      expect(result).to eq("Fallback")

      expect(@error).to eq(nil)
    end
  end

  context "when fallback is not provided" do
    let(:fallback) { nil }

    it "records and raises the error" do
      expect { result }.to raise_error(Stoplight::Domain::Error::RedLight, config.name) { |error|
        expect(error.cool_off_time).to eq(config.cool_off_time)
        expect(error.retry_after).to eq(metadata.recovery_scheduled_after)
      }
    end
  end
end
