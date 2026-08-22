# frozen_string_literal: true

RSpec.describe Stoplight::Admin::Actions::Stats do
  subject(:call) { action.call }

  let(:action) { described_class.new(config_registry:, storage:, lights_stats: Stoplight::Admin::LightsStats) }
  let(:config_registry) { instance_double(Stoplight::Admin::ConfigRegistry) }
  let(:storage) { instance_double(Stoplight::Wiring::System::Storage) }

  before do
    allow(config_registry).to receive(:all).and_return(configs)
  end

  context "when there are no lights" do
    let(:configs) { [] }

    it "returns no lights" do
      lights, = call

      expect(lights).to eq([])
    end

    it "returns empty stats" do
      _, stats = call

      expect(stats).to eq(Stoplight::Admin::LightsStats::EMPTY_STATS)
    end
  end

  context "when there are lights" do
    let(:config) { instance_double(Stoplight::Domain::Config, id: "light-id", name: "foo") }
    let(:configs) { [config] }
    let(:state_snapshot) do
      instance_double(Stoplight::Domain::StateSnapshot, color: "green", locked_state: "unlocked")
    end
    let(:metrics_snapshot) do
      instance_double(Stoplight::Domain::MetricsSnapshot, last_error: nil, consecutive_errors: 0)
    end
    let(:recovery_metrics_snapshot) { instance_double(Stoplight::Domain::MetricsSnapshot) }

    before do
      allow(storage).to receive(:state_snapshot).with(config).and_return(state_snapshot)
      allow(storage).to receive(:metrics_snapshot).with(config).and_return(metrics_snapshot)
      allow(storage).to receive(:recovery_metrics_snapshot).with(config).and_return(recovery_metrics_snapshot)
    end

    it "builds a light view from the config and its storage snapshots" do
      lights, = call

      expect(lights).to contain_exactly(
        have_attributes(
          id: "light-id", name: "foo", color: "green", state: "unlocked", failures: [], failure_count: 0
        )
      )
    end

    it "computes stats over the lights" do
      _, stats = call

      expect(stats).to eq(Stoplight::Admin::LightsStats::EMPTY_STATS.merge(count_green: 1, percent_green: 100))
    end
  end
end
