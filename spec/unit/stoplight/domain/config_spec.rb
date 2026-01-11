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
      traffic_control: instance_double(NullTrafficControl),
      traffic_recovery: instance_double(NullTrafficRecovery),
      error_notifier: ->(e) {},
      notifiers: [],
      data_store: double("config"),
      **settings
    )
  end

  describe "#cool_off_time_in_milliseconds" do
    subject { config.cool_off_time_in_milliseconds }

    let(:config) { config_factory(cool_off_time:) }
    let(:cool_off_time) { 1 }

    it { is_expected.to eq(1_000) }
  end
end
