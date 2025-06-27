# frozen_string_literal: true

RSpec.describe Stoplight::Light::Config do
  let(:config) { described_class.new(**settings) }

  let(:settings) do
    {
      name:,
      cool_off_time:,
      data_store:,
      error_notifier:,
      notifiers:,
      threshold:,
      window_size:,
      tracked_errors:,
      skipped_errors:,
      traffic_control:,
      traffic_recovery:
    }
  end

  let(:name) { "foobar" }
  let(:cool_off_time) { Stoplight::Default::COOL_OFF_TIME }
  let(:data_store) { Stoplight::Default::DATA_STORE }
  let(:error_notifier) { Stoplight::Default::ERROR_NOTIFIER }
  let(:notifiers) { Stoplight::Default::NOTIFIERS }
  let(:threshold) { Stoplight::Default::THRESHOLD }
  let(:window_size) { Stoplight::Default::WINDOW_SIZE }
  let(:tracked_errors) { Stoplight::Default::TRACKED_ERRORS }
  let(:skipped_errors) { Stoplight::Default::SKIPPED_ERRORS }
  let(:traffic_control) { Stoplight::Default::TRAFFIC_CONTROL }
  let(:traffic_recovery) { Stoplight::Default::TRAFFIC_RECOVERY }

  describe "#track_error?" do
    subject { config.track_error?(error) }

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
end
