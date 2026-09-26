# frozen_string_literal: true

RSpec.describe Stoplight::Domain::ErrorTrackingPolicy do
  let(:policy) { described_class.new(tracked: tracked_errors, skipped: skipped_errors) }

  describe "#track?" do
    subject { policy.track?(error) }

    context "when the error is in skipped_errors" do
      let(:error) { skipped_errors.first.new }
      let(:skipped_errors) { [StandardError] }
      let(:tracked_errors) { [StandardError] }

      it { is_expected.to be false }
    end

    context "when the error is in tracked_errors but not in skipped_errors" do
      let(:error) { tracked_errors.first.new }
      let(:skipped_errors) { [RuntimeError] }
      let(:tracked_errors) { [StandardError] }

      it { is_expected.to be true }
    end

    context "when the error is in neither tracked_errors nor skipped_errors" do
      let(:error) { RuntimeError.new }
      let(:skipped_errors) { [StandardError] }
      let(:tracked_errors) { [ArgumentError] }

      it { is_expected.to be false }
    end

    context "when skipped_errors is empty" do
      let(:error) { StandardError.new }
      let(:skipped_errors) { [] }
      let(:tracked_errors) { [StandardError] }

      it { is_expected.to be true }
    end

    context "when tracked_errors is empty" do
      let(:error) { StandardError.new }
      let(:skipped_errors) { [StandardError] }
      let(:tracked_errors) { [] }

      it { is_expected.to be false }
    end
  end

  describe "#with" do
    let(:tracked_errors) { [StandardError] }
    let(:skipped_errors) { [Timeout::Error] }

    it "returns itself when no overrides are provided" do
      expect(policy.with).to equal(policy)
    end

    it "replaces tracked errors and preserves skipped errors" do
      overridden = policy.with(tracked: KeyError)

      expect(overridden).to satisfy { |candidate|
        candidate.track?(KeyError.new) &&
          !candidate.track?(ArgumentError.new) &&
          !candidate.track?(Timeout::Error.new)
      }
    end

    it "replaces skipped errors and preserves tracked errors" do
      overridden = policy.with(skipped: KeyError)

      expect(overridden).to satisfy { |candidate|
        candidate.track?(Timeout::Error.new) &&
          candidate.track?(ArgumentError.new) &&
          !candidate.track?(KeyError.new)
      }
    end
  end
end
