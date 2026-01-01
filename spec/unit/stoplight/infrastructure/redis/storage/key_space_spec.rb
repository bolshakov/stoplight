# frozen_string_literal: true

RSpec.describe Stoplight::Infrastructure::Redis::Storage::KeySpace do
  describe ".build" do
    subject(:key_space) { described_class.build(system_name:, light_name:) }

    let(:light_name) { "Light name" }
    let(:system_name) { "System name" }

    specify "#system_id" do
      expect(key_space.system_id).to eq("69186998727c")
    end

    specify "#light_id" do
      expect(key_space.light_id).to eq("92f3a0b4cde3")
    end
  end

  describe "#key" do
    subject { key_space.key(*pieces) }

    let(:key_space) { described_class.new(system_id: "system", light_id: "light") }

    context "with a pattern" do
      let(:pieces) { ["*"] }

      it { is_expected.to eq("stoplight:v6:system:light:*") }
    end

    context "with one piece" do
      let(:pieces) { ["metadata"] }

      it { is_expected.to eq("stoplight:v6:system:light:metadata") }
    end

    context "with multiple pieces" do
      let(:pieces) { ["this", "that"] }

      it { is_expected.to eq("stoplight:v6:system:light:this:that") }
    end
  end
end
