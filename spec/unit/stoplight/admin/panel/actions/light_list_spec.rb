# frozen_string_literal: true

RSpec.describe Stoplight::Admin::Panel::Actions::LightList do
  subject(:call) { action.call }

  let(:action) { described_class.new(config_registry:, storage:) }
  let(:config_registry) { instance_double(Stoplight::Admin::ConfigRegistry) }
  let(:storage) { instance_double(Stoplight::Wiring::System::Storage) }

  before do
    allow(config_registry).to receive(:all).and_return(configs)
  end

  context "when there are no lights" do
    let(:configs) { [] }

    it "returns no lights" do
      expect(call).to eq([])
    end
  end

  context "when there are lights" do
    let(:config) { instance_double(Stoplight::Domain::Config, id: "light-id", name: "foo") }
    let(:configs) { [config] }
    let(:state_snapshot) { instance_double(Stoplight::Domain::StateSnapshot, color: Stoplight::Color::GREEN) }

    before do
      allow(storage).to receive(:state_snapshot).with(config).and_return(state_snapshot)
    end

    it "builds a light from the config and its state snapshot only" do
      expect(call).to contain_exactly(
        have_attributes(id: "light-id", name: "foo", color: Stoplight::Color::GREEN)
      )
    end
  end

  context "with several lights" do
    let(:red_config) { instance_double(Stoplight::Domain::Config, id: "red-id", name: "Zebra") }
    let(:yellow_config) { instance_double(Stoplight::Domain::Config, id: "yellow-id", name: "Yak") }
    let(:green_a_config) { instance_double(Stoplight::Domain::Config, id: "green-a-id", name: "Bear") }
    let(:green_b_config) { instance_double(Stoplight::Domain::Config, id: "green-b-id", name: "Ant") }
    let(:configs) { [green_a_config, red_config, green_b_config, yellow_config] }

    before do
      allow(storage).to receive(:state_snapshot).with(red_config)
        .and_return(instance_double(Stoplight::Domain::StateSnapshot, color: Stoplight::Color::RED))
      allow(storage).to receive(:state_snapshot).with(yellow_config)
        .and_return(instance_double(Stoplight::Domain::StateSnapshot, color: Stoplight::Color::YELLOW))
      allow(storage).to receive(:state_snapshot).with(green_a_config)
        .and_return(instance_double(Stoplight::Domain::StateSnapshot, color: Stoplight::Color::GREEN))
      allow(storage).to receive(:state_snapshot).with(green_b_config)
        .and_return(instance_double(Stoplight::Domain::StateSnapshot, color: Stoplight::Color::GREEN))
    end

    it "orders worst color first, then by name" do
      expect(call.map(&:name)).to eq(["Zebra", "Yak", "Ant", "Bear"])
    end
  end
end
