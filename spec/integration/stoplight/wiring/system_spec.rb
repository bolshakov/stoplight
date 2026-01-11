# frozen_string_literal: true

RSpec.describe Stoplight::Wiring::System do
  subject(:system) { described_class.new("system name", settings:) }
  let(:settings) do
    Stoplight::Wiring::Settings.new(
      name: Stoplight::Common.none,
      cool_off_time:,
      threshold:,
      recovery_threshold:,
      window_size:,
      tracked_errors:,
      skipped_errors:,
      data_store:,
      error_notifier:,
      notifiers:,
      traffic_control:,
      traffic_recovery:
    )
  end
  let(:cool_off_time) { Stoplight::Common.none }
  let(:threshold) { Stoplight::Common.none }
  let(:recovery_threshold) { Stoplight::Common.none }
  let(:window_size) { Stoplight::Common.none }
  let(:tracked_errors) { Stoplight::Common.none }
  let(:skipped_errors) { Stoplight::Common.none }
  let(:data_store) { Stoplight::Common.none }
  let(:error_notifier) { Stoplight::Common.none }
  let(:notifiers) { Stoplight::Common.none }
  let(:traffic_control) { Stoplight::Common.none }
  let(:traffic_recovery) { Stoplight::Common.none }

  describe "#new" do
    let(:traffic_control) { Stoplight::Common.some(:error_rate) }
    let(:threshold) { Stoplight::Common.some(1) }

    it "validates system configuration" do
      expect { system }.to raise_error(Stoplight::Error::ConfigurationError)
    end
  end
end
