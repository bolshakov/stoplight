# frozen_string_literal: true

RSpec.describe Stoplight::Admin::Actions::LockGreen do
  subject(:call) { action.call(params) }

  let(:action) { described_class.new(lights_repository: lights_repository) }
  let(:lights_repository) { instance_double(Stoplight::Admin::LightsRepository) }
  let(:params) { {names: names} }

  context "when just one light name is provided" do
    let(:names) { "testing-light" }

    it "locks this light green" do
      expect(lights_repository).to receive(:lock).with("testing-light", "green")

      call
    end
  end

  context "when two lights are provided" do
    let(:names) { ["testing-light-1", "testing-light-2"] }

    it "locks these lights green" do
      expect(lights_repository).to receive(:lock).with("testing-light-1", "green")
      expect(lights_repository).to receive(:lock).with("testing-light-2", "green")

      call
    end
  end

  context "when the light name is has escape characters" do
    let(:names) { "testing%3Dlight" }

    it "unescapes it and locks this light green" do
      expect(lights_repository).to receive(:lock).with("testing=light", "green")

      call
    end
  end
end
