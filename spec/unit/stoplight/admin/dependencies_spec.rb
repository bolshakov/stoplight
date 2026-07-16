# frozen_string_literal: true

RSpec.describe Stoplight::Admin::Dependencies do
  subject(:dependencies) { described_class.new(system:) }

  let(:system) { Stoplight.__stoplight__system(SecureRandom.uuid) }

  describe "#lights_repository" do
    it "wires the repository against the system's own config" do
      name = "dependencies-light"
      system.light(name, threshold: 10)

      repository = dependencies.lights_repository

      expect { repository.lock(name) }.not_to raise_error
    end
  end
end
