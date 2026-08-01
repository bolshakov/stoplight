# frozen_string_literal: true

RSpec.describe Stoplight::Admin::Actions::Lock do
  subject(:call) { action.call(params) }

  let(:action) { described_class.new(lights_repository: lights_repository) }
  let(:lights_repository) { instance_double(Stoplight::Admin::LightsRepository) }
  let(:params) { {ids: ids} }

  context "when just one light name is provided" do
    let(:ids) { "testing-light" }

    it "locks this light" do
      expect(lights_repository).to receive(:lock).with("testing-light")

      call
    end
  end

  context "when two lights are provided" do
    let(:ids) { ["testing-light-1", "testing-light-2"] }

    it "locks these lights" do
      expect(lights_repository).to receive(:lock).with("testing-light-1")
      expect(lights_repository).to receive(:lock).with("testing-light-2")

      call
    end
  end
end
