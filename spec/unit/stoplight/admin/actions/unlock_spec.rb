# frozen_string_literal: true

RSpec.describe Stoplight::Admin::Actions::Unlock do
  subject(:call) { action.call(params) }

  let(:action) { described_class.new(lights_repository: lights_repository) }
  let(:lights_repository) { instance_double(Stoplight::Admin::LightsRepository) }
  let(:params) { {ids: ids} }

  context "when just one light name is provided" do
    let(:id) { SecureRandom.uuid }
    let(:ids) { id }

    it "unlocks this light" do
      expect(lights_repository).to receive(:unlock).with(id)

      call
    end
  end

  context "when two lights are provided" do
    let(:id1) { SecureRandom.uuid }
    let(:id2) { SecureRandom.uuid }
    let(:ids) { [id1, id2] }

    it "unlocks these lights" do
      expect(lights_repository).to receive(:unlock).with(id1)
      expect(lights_repository).to receive(:unlock).with(id2)

      call
    end
  end

  context "when the light name is has escape characters" do
    let(:ids) { SecureRandom.uuid }

    it "unescapes it and unlocks this light" do
      expect(lights_repository).to receive(:unlock).with(ids)

      call
    end
  end
end
