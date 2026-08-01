# frozen_string_literal: true

RSpec.describe Stoplight::Admin::Actions::LockGreen do
  subject(:call) { action.call(params) }

  let(:action) { described_class.new(lights_repository: lights_repository) }
  let(:lights_repository) { instance_double(Stoplight::Admin::LightsRepository) }
  let(:params) { {ids: ids} }

  context "when just one light name is provided" do
    let(:ids) { "testing-light" }

    it "locks this light green" do
      expect(lights_repository).to receive(:lock).with("testing-light", "green")

      call
    end
  end

  context "when two lights are provided" do
    let(:ids) { ["testing-light-1", "testing-light-2"] }

    it "locks these lights green" do
      expect(lights_repository).to receive(:lock).with("testing-light-1", "green")
      expect(lights_repository).to receive(:lock).with("testing-light-2", "green")

      call
    end
  end
end
