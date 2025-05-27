# frozen_string_literal: true

RSpec.describe Stoplight::Admin::Actions::Lock do
  subject(:call) { action.call(params) }

  let(:action) { described_class.new(lights_repository: lights_repository) }
  let(:lights_repository) { instance_double(Stoplight::Admin::LightsRepository) }
  let(:params) { {names: names} }

  context "when just one light name is provided" do
    let(:names) { "testing-light" }

    it "locks this light" do
      expect(lights_repository).to receive(:lock).with("testing-light")

      call
    end
  end

  context "when two lights are provided" do
    let(:names) { ["testing-light-1", "testing-light-2"] }

    it "locks these lights" do
      expect(lights_repository).to receive(:lock).with("testing-light-1")
      expect(lights_repository).to receive(:lock).with("testing-light-2")

      call
    end
  end

  context "when the light name is has escape characters" do
    let(:names) { "testing%3Dlight" }

    it "unescapes it and locks this light" do
      expect(lights_repository).to receive(:lock).with("testing=light")

      call
    end
  end
end
