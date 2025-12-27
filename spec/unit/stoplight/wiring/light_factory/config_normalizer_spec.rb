# frozen_string_literal: true

RSpec.describe Stoplight::Wiring::LightFactory::ConfigNormalizer do
  describe "tracked_errors" do
    subject(:tracked_errors_out) { described_class.call(config).tracked_errors }

    let(:config) { Stoplight::Wiring::Light::DefaultConfig.with(tracked_errors:) }

    context "when array" do
      let(:tracked_errors) { [KeyError, NotImplementedError] }

      it { is_expected.to eq(tracked_errors) }
    end

    context "when single value" do
      let(:tracked_errors) { KeyError }

      it { is_expected.to eq([tracked_errors]) }
    end
  end

  describe "skipped_errors" do
    subject(:skipped_errors_out) { described_class.call(config).skipped_errors }

    let(:config) { Stoplight::Wiring::Light::DefaultConfig.with(skipped_errors:) }

    context "when array" do
      let(:skipped_errors) { [KeyError, NotImplementedError] }

      it { is_expected.to eq(skipped_errors) }
    end

    context "when single value" do
      let(:skipped_errors) { KeyError }

      it { is_expected.to eq([skipped_errors]) }
    end
  end

  describe "cool_off_time" do
    subject(:cool_off_time_out) { described_class.call(config).cool_off_time }

    let(:config) { Stoplight::Wiring::Light::DefaultConfig.with(cool_off_time:) }

    context "when Integer" do
      let(:cool_off_time) { 42 }

      it { is_expected.to eq(cool_off_time) }
    end

    context "when not integer" do
      let(:cool_off_time) { 42.2 }

      it { is_expected.to eq(42) }
    end
  end
end
