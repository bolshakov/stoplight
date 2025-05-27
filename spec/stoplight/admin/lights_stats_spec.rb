# frozen_string_literal: true

RSpec.describe Stoplight::Admin::LightsStats do
  subject(:light_stats) { described_class.new(lights) }

  describe "#call" do
    subject(:stats) { light_stats.call }

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
          Stoplight::Admin::LightsRepository::Light.new(
            name: "green",
            color: "green",
            state: "unlocked",
            failures: []
          ),
          Stoplight::Admin::LightsRepository::Light.new(
            name: "yellow",
            color: "yellow",
            state: "unlocked",
            failures: []
          ),
          Stoplight::Admin::LightsRepository::Light.new(
            name: "red",
            color: "red",
            state: "locked",
            failures: []
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
end
