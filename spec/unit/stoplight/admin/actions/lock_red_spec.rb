# frozen_string_literal: true

RSpec.describe Stoplight::Admin::Actions::LockRed do
  subject(:call) { action.call(params) }

  let(:action) { described_class.new(lights_repository: lights_repository) }
  let(:lights_repository) { instance_double(Stoplight::Admin::LightsRepository) }
  let(:params) { {ids: ids} }

  context "when just one light name is provided" do
    let(:ids) { "testing-light" }

    it "locks this light red" do
      expect(lights_repository).to receive(:lock).with("testing-light", "red")

      call
    end
  end

  context "when two lights are provided" do
    let(:ids) { ["testing-light-1", "testing-light-2"] }

    it "locks these lights red" do
      expect(lights_repository).to receive(:lock).with("testing-light-1", "red")
      expect(lights_repository).to receive(:lock).with("testing-light-2", "red")

      call
    end
  end
end
