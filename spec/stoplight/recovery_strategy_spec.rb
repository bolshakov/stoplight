# frozen_string_literal: true

require "spec_helper"

RSpec.describe Stoplight::RecoveryStrategy do
  subject(:evaluate) { described_class.new.evaluate(nil, metadata) }

  let(:metadata) do
    instance_double(Stoplight::Metadata,
      recovery_started_at:,
      last_success_at:)
  end

  context "when there was a successful recovery probe during recovery phase" do
    let(:last_success_at) { Time.now }
    let(:recovery_started_at) { last_success_at - 1 }

    it { is_expected.to eq(Stoplight::Color::GREEN) }
  end

  context "when there were no successful recovery probe during recovery phase" do
    let(:last_success_at) { recovery_started_at - 1 }
    let(:recovery_started_at) { Time.now }

    it { is_expected.to eq(Stoplight::Color::RED) }
  end
end
