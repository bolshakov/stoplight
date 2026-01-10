# frozen_string_literal: true

RSpec.describe Stoplight::Infrastructure::Storage::CompatibilityState do
  subject(:store) { described_class.new(data_store:, config:) }

  let(:config) { instance_double(Stoplight::Domain::Config) }
  let(:data_store) { instance_double(NullDataStore) }

  describe "#state_snapshot" do
    subject { store.state_snapshot }

    let(:state_snapshot) { instance_double(Stoplight::Domain::StateSnapshot) }

    it "delegates to data store" do
      expect(data_store).to receive(:get_state_snapshot).with(config).and_return(state_snapshot)

      is_expected.to eq(state_snapshot)
    end
  end

  describe "#set_state" do
    subject { store.set_state("locked_green") }

    let(:state_set) { double("locked_green") }

    it "delegates to data store" do
      expect(data_store).to receive(:set_state).with(config, "locked_green").and_return(state_set)

      is_expected.to eq(state_set)
    end
  end

  describe "#transition_to_color" do
    subject { store.transition_to_color("green") }

    let(:transitioned) { double("bool") }

    it "delegates to data store" do
      expect(data_store).to receive(:transition_to_color).with(config, "green").and_return(transitioned)

      is_expected.to eq(transitioned)
    end
  end

  describe "#clear" do
    it "delegates to data store" do
      expect(data_store).to receive(:delete_light).with(config)

      store.clear
    end
  end
end
