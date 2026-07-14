# frozen_string_literal: true

RSpec.describe Stoplight::Infrastructure::Redis::Storage::SystemKeySpace do
  describe ".build" do
    subject { described_class.build(system_name: system_name) }

    let(:system_name) { "ABCD" }

    it { is_expected.to be_a(described_class).and have_attributes(system_id: instance_of(String)) }
  end

  describe ".hash_name" do
    subject { described_class.hash_name(name) }

    let(:name) { "ABCD" }

    it { is_expected.to be_a(String).and have_attributes(size: 12) }
  end

  describe "#key" do
    subject { described_class.build(system_name: system_name).key(pieces) }

    let(:system_name) { "ABCD" }
    let(:pieces) { %w[a b] }

    it { is_expected.to eq("stoplight:v5:e12e115acf45:a:b") }
  end
end
