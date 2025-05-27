# frozen_string_literal: true

RSpec.describe Stoplight::Admin::LightsRepository::Light do
  subject(:light) do
    described_class.new(
      name: name,
      color: color,
      state: state,
      failures: failures
    )
  end
  let(:failures) { [] }
  let(:color) { "green" }
  let(:name) { "light-specs" }

  describe "#locked?" do
    context "when locked green" do
      let(:state) { "locked_green" }

      it { is_expected.to be_locked }
    end

    context "when locked red" do
      let(:state) { "locked_green" }

      it { is_expected.to be_locked }
    end

    context "when unlocked" do
      let(:state) { "unlocked" }

      it { is_expected.not_to be_locked }
    end
  end
end
