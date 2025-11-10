# frozen_string_literal: true

RSpec.describe Stoplight::Admin::Actions::Remove do
  subject(:call) { action.call(params) }

  let(:action) { described_class.new(lights_repository: lights_repository) }
  let(:lights_repository) { instance_double(Stoplight::Admin::LightsRepository) }
  let(:params) { {names: names} }

  context "when just one light name is provided" do
    let(:names) { "testing-light" }

    it "removes this light" do
      expect(lights_repository).to receive(:remove).with("testing-light")

      call
    end
  end

  context "when two lights are provided" do
    let(:names) { ["testing-light-1", "testing-light-2"] }

    it "removes these lights" do
      expect(lights_repository).to receive(:remove).with("testing-light-1")
      expect(lights_repository).to receive(:remove).with("testing-light-2")

      call
    end
  end

  context "when the light name has escape characters" do
    let(:names) { "testing%3Dlight" }

    it "unescapes it and removes this light" do
      expect(lights_repository).to receive(:remove).with("testing=light")

      call
    end
  end
end
