# frozen_string_literal: true

require "spec_helper"

RSpec.describe Stoplight::Config do
  describe "#default" do
    let(:config) { described_class.new }

    context "when not configured" do
      it "returns an empty configuration hash" do
        expect(config.default).to eq({})
      end
    end

    context "when configured" do
      let(:config) do
        described_class.new(
          default: {
            window_size: 664
          }
        )
      end

      it "returns only configured values" do
        expect(config.default).to eq(window_size: 664)
      end
    end
  end

  describe "#configure_light" do
    let(:config) do
      described_class.new(
        default: {
          window_size: 664,
          threshold: 7
        }
      )
    end

    context "when the configuration option is defined on the defaults level" do
      subject(:light_config) { config.configure_light("light1") }

      it "returns individual config with default as a fallback" do
        is_expected.to eq(
          Stoplight::Light::Config.new(
            name: "light1",
            window_size: 664,
            threshold: 7
          )
        )
      end
    end

    context "when the configuration option is defined only on the default level and overrides provided" do
      subject(:light_config) { config.configure_light("light2", threshold: 2, cool_off_time: 14.0) }

      it "returns individual config with default as a fallback and provided overrides" do
        is_expected.to eq(
          Stoplight::Light::Config.new(
            name: "light2",
            window_size: 664,
            cool_off_time: 14.0,
            threshold: 2
          )
        )
      end
    end
  end
end
