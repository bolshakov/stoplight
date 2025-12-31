# frozen_string_literal: true

RSpec.describe Stoplight::Domain::Config do
  def config_factory(**settings)
    described_class.new(
      name: "PROTITYPE",
      cool_off_time: 60,
      threshold: 3,
      recovery_threshold: 1,
      window_size: nil,
      tracked_errors: [StandardError],
      skipped_errors: [],
      **settings
    )
  end
  describe "#track_error?" do
    subject { config.track_error?(error) }

    let(:config) { config_factory(skipped_errors:, tracked_errors:) }

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

  describe "#cool_off_time_in_milliseconds" do
    subject { config.cool_off_time_in_milliseconds }

    let(:config) { config_factory(cool_off_time:) }
    let(:cool_off_time) { 1 }

    it { is_expected.to eq(1_000) }
  end
end
