# frozen_string_literal: true

RSpec.describe Stoplight::Admin::Actions::LockAllGreen do
  subject(:call) { action.call }

  let(:action) { described_class.new(lights_repository: lights_repository) }
  let(:lights_repository) { instance_double(Stoplight::Admin::LightsRepository) }

  let(:red_light) { instance_double(Stoplight::Admin::LightsRepository::Light, name: "red-light") }
  let(:yellow_light) { instance_double(Stoplight::Admin::LightsRepository::Light, name: "yellow-light") }

  it "fetches red and yellow lights and lock them green" do
    expect(lights_repository).to receive(:with_color).with("red", "yellow") { [red_light, yellow_light] }
    expect(lights_repository).to receive(:lock).with("red-light", "green")
    expect(lights_repository).to receive(:lock).with("yellow-light", "green")

    call
  end
end
