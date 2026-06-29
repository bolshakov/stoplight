# frozen_string_literal: true

RSpec.describe Stoplight::Infrastructure::Redis::Storage::Registry, :redis do
  subject(:registry) { described_class.new(redis:, key_space:, clock:) }

  let(:key_space) { Stoplight::Infrastructure::Redis::Storage::SystemKeySpace.new(system_id: SecureRandom.uuid) }
  let(:clock) { Stoplight::Infrastructure::SystemClock.new }

  describe "#names" do
    subject { registry.names }

    context "when no lights have been registered" do
      it { is_expected.to eq([]) }
    end

    context "when a light has been registered" do
      before { registry.register("stripe", config: nil) }

      it { is_expected.to contain_exactly("stripe") }
    end

    context "when a light has been unregistered" do
      before do
        registry.register("stripe", config: nil)
        registry.unregister("stripe")
      end

      it { is_expected.not_to include("stripe") }
    end

    context "when the same light is registered twice" do
      before do
        registry.register("stripe", config: nil)
        registry.register("stripe", config: nil)
      end

      it { is_expected.to contain_exactly("stripe") }
    end

    context "when two different lights are registered" do
      before do
        registry.register("stripe", config: nil)
        registry.register("paypal", config: nil)
      end

      it { is_expected.to contain_exactly("stripe", "paypal") }
    end
  end
end
