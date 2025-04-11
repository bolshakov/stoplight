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

  describe "#lights" do
    context "without any light configs" do
      let(:config) { described_class.new }

      it "returns an empty hash" do
        expect(config.lights).to eq({})
      end
    end

    context "with light config" do
      let(:config) do
        described_class.new(
          lights: {
            "light1" => {
              window_size: 664
            }
          }
        )
      end

      it "returns a hash with the light name and its config" do
        expect(config.lights).to eq(
          "light1" => {window_size: 664}
        )
      end
    end
  end

  describe "#config_for_light" do
    let(:config) do
      described_class.new(
        default: {
          window_size: 664
        },
        lights: {
          "light1" => {
            window_size: 100,
            cool_off_time: 30
          },
          "light2" => {
            cool_off_time: 54
          }
        }
      )
    end

    context "when the configuration option is defined on the defaults and light level" do
      subject(:light_config) { config.configure_light("light1") }

      it "returns individual config with default as a fallback" do
        is_expected.to eq(
          Stoplight::Light::Config.new(
            name: "light1",
            window_size: 100,
            cool_off_time: 30.0
          )
        )
      end
    end

    context "when the configuration option is defined only on the light level" do
      subject(:light_config) { config.configure_light("light2") }

      it "returns individual config with default as a fallback" do
        is_expected.to eq(
          Stoplight::Light::Config.new(
            name: "light2",
            window_size: 664,
            cool_off_time: 54.0
          )
        )
      end
    end

    context "when the configuration option is defined only on the light level and overrides provided" do
      subject(:light_config) { config.configure_light("light2", cool_off_time: 14.0) }

      it "returns individual config with default as a fallback and provided overrides" do
        is_expected.to eq(
          Stoplight::Light::Config.new(
            name: "light2",
            window_size: 664,
            cool_off_time: 14.0
          )
        )
      end
    end

    context "when the light is not configured" do
      subject(:light_config) { config.configure_light("unknown_light") }

      it "returns the default config if no specific config is found" do
        is_expected.to eq(
          Stoplight::Light::Config.new(
            name: "unknown_light",
            window_size: 664
          )
        )
      end
    end

    context "when the light is not configured and overrides provided" do
      subject(:light_config) { config.configure_light("unknown_light", cool_off_time: 14.0) }

      it "returns the default config if no specific config is found" do
        is_expected.to eq(
          Stoplight::Light::Config.new(
            name: "unknown_light",
            window_size: 664,
            cool_off_time: 14.0
          )
        )
      end
    end
  end
end
