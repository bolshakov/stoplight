# frozen_string_literal: true

RSpec.describe Stoplight::TrafficControl::ErrorRate do
  describe "#check_compatibility" do
    subject(:strategy) { described_class.new.check_compatibility(config) }

    let(:config) { instance_double(Stoplight::Light::Config, window_size:) }

    context "when stoplight tracks running window" do
      let(:window_size) { 600 }

      it { is_expected.to be_compatible }
    end

    context "when stoplight does not track running window" do
      let(:window_size) { nil }

      it { is_expected.to be_incompatible }

      it "returns an error message" do
        expect(strategy.error_messages).to eq("`window_size` should be set")
      end
    end
  end
end
