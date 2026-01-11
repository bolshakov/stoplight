# frozen_string_literal: true

RSpec.describe Stoplight::Domain::Strategies::RedRunStrategy, :freeze do
  subject(:result) { strategy.execute(fallback, state_snapshot:) { 42 } }

  let(:strategy) { described_class.new(name:, cool_off_time:) }
  let(:state_snapshot) { instance_double(Stoplight::Domain::StateSnapshot, recovery_scheduled_after: Time.now) }
  let(:name) { SecureRandom.uuid }
  let(:cool_off_time) { 60 }

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
      expect { result }.to raise_error(Stoplight::Error::RedLight, name) { |error|
        expect(error.cool_off_time).to eq(cool_off_time)
        expect(error.retry_after).to eq(state_snapshot.recovery_scheduled_after)
      }
    end
  end
end
