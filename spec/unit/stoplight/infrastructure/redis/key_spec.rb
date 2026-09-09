# frozen_string_literal: true

RSpec.describe Stoplight::Infrastructure::Redis::Key do
  describe ".new" do
    context "without segments" do
      subject(:key) { described_class.new }

      it { is_expected.to eq("") }
    end

    context "with one string segment" do
      subject(:key) { described_class.new("stoplight") }

      it { is_expected.to eq("stoplight") }
    end

    context "with multiple mixed segment" do
      subject(:key) { described_class.new("stoplight", :v42, 64) }

      it { is_expected.to eq("stoplight:v42:64") }
    end
  end

  describe "#join" do
    subject { base_key.join(*segments) }

    let(:base_key) { described_class.new(:stoplight, :v0) }

    context "with a pattern" do
      let(:segments) { ["*"] }

      it { is_expected.to eq("stoplight:v0:*") }
    end

    context "with one segment" do
      let(:segments) { ["metadata"] }

      it { is_expected.to eq("stoplight:v0:metadata") }
    end

    context "with multiple segments" do
      let(:segments) { ["{this}", :that] }

      it { is_expected.to eq("stoplight:v0:{this}:that") }
    end
  end
end
