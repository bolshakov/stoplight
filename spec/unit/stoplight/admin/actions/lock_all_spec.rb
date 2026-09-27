# frozen_string_literal: true

RSpec.describe Stoplight::Admin::Actions::LockAll do
  subject(:call) { action.call(color: Stoplight::Color::GREEN) }

  let(:action) { described_class.new(config_registry:, storage:) }
  let(:config_registry) { instance_double(Stoplight::Admin::ConfigRegistry) }
  let(:storage) { instance_double(Stoplight::Wiring::System::Storage) }

  let(:red_light) { instance_double(Stoplight::Domain::Config, id: SecureRandom.uuid) }
  let(:red_light_state_snapshot) { instance_double(Stoplight::Domain::StateSnapshot, color: Stoplight::Color::RED) }

  let(:yellow_light) { instance_double(Stoplight::Domain::Config, id: SecureRandom.uuid) }
  let(:yellow_light_state_snapshot) { instance_double(Stoplight::Domain::StateSnapshot, color: Stoplight::Color::YELLOW) }

  let(:green_light) { instance_double(Stoplight::Domain::Config, id: SecureRandom.uuid) }
  let(:green_light_state_snapshot) { instance_double(Stoplight::Domain::StateSnapshot, color: Stoplight::Color::GREEN) }

  it "fetches red and yellow lights and lock them green" do
    expect(config_registry).to receive(:all).and_return([red_light, yellow_light, green_light])
    expect(storage).to receive(:state_snapshot).with(red_light).and_return(red_light_state_snapshot)
    expect(storage).to receive(:state_snapshot).with(yellow_light).and_return(yellow_light_state_snapshot)
    expect(storage).to receive(:state_snapshot).with(green_light).and_return(green_light_state_snapshot)

    expect(storage).to receive(:lock).with(red_light, Stoplight::Color::GREEN)
    expect(storage).to receive(:lock).with(yellow_light, Stoplight::Color::GREEN)

    call
  end

  context "when color is red" do
    subject(:call) { action.call(color: Stoplight::Color::RED) }

    it "throws halt without fetching or locking any light" do
      expect(config_registry).not_to receive(:all)
      expect(storage).not_to receive(:lock)

      expect do
        call
      end.to throw_symbol(:halt, 400)
    end
  end

  context "when color is not lockable" do
    subject(:call) { action.call(color: Stoplight::Color::YELLOW) }

    it "throws halt without fetching or locking any light" do
      expect(config_registry).not_to receive(:all)
      expect(storage).not_to receive(:lock)

      expect do
        call
      end.to throw_symbol(:halt, 400)
    end
  end
end
