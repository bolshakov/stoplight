# frozen_string_literal: true

RSpec.describe Stoplight::Admin::LightsStats do
  shared_examples Stoplight::Admin::LightsStats do
    context "when there are no lights" do
      let(:lights) { [] }

      it "returns empty stats" do
        is_expected.to eq(
          count_red: 0, count_yellow: 0, count_green: 0,
          percent_red: 0, percent_yellow: 0, percent_green: 0
        )
      end
    end

    context "when there are lights" do
      let(:lights) do
        [
          Stoplight::Admin::LightView.new(
            id: "a",
            config: instance_double(Stoplight::Domain::Config, name: "green"),
            color: "green",
            state: "unlocked",
            failures: [],
            state_snapshot: instance_double(Stoplight::Domain::StateSnapshot),
            recovery_metrics_snapshot: nil
          ),
          Stoplight::Admin::LightView.new(
            id: "b",
            config: instance_double(Stoplight::Domain::Config, name: "yellow"),
            color: "yellow",
            state: "unlocked",
            failures: [],
            state_snapshot: instance_double(Stoplight::Domain::StateSnapshot),
            recovery_metrics_snapshot: instance_double(Stoplight::Domain::MetricsSnapshot, requests: 4)
          ),
          Stoplight::Admin::LightView.new(
            id: "c",
            config: instance_double(Stoplight::Domain::Config, name: "red"),
            color: "red",
            state: "locked",
            failures: [],
            state_snapshot: instance_double(Stoplight::Domain::StateSnapshot),
            recovery_metrics_snapshot: nil
          )
        ]
      end

      it "calculates stats" do
        is_expected.to eq(
          count_red: 1,
          count_yellow: 1,
          count_green: 1,
          percent_red: 34,
          percent_yellow: 34,
          percent_green: 34
        )
      end
    end
  end

  it_behaves_like Stoplight::Admin::LightsStats, "#call" do
    subject(:light_stats) { described_class.new(lights) }
    subject(:stats) { light_stats.call }
  end

  it_behaves_like Stoplight::Admin::LightsStats, ".call" do
    subject(:stats) { described_class.new(lights).call }
  end
end
