# frozen_string_literal: true

RSpec.describe Stoplight::Admin::Actions::Lock do
  subject(:call) { action.call(light_id:, color:) }

  let(:action) { described_class.new(config_registry:, storage:) }
  let(:config_registry) { instance_double(Stoplight::Admin::ConfigRegistry) }
  let(:storage) { instance_double(Stoplight::Wiring::System::Storage) }
  let(:light_id) { SecureRandom.uuid }
  let(:color) { "green" }

  before do
    allow(config_registry).to receive(:find_by_id).with(light_id).and_return(config)
  end

  context "when existing light id is provided" do
    let(:config) { instance_double(Stoplight::Domain::Config) }

    it "locks this light" do
      expect(storage).to receive(:lock).with(config, color)

      call
    end
  end

  context "when light does not exists" do
    let(:config) { nil }

    it "throws halt" do
      expect(storage).not_to receive(:lock)

      expect do
        call
      end.to throw_symbol(:halt, 404)
    end
  end

  context "when color is not lockable" do
    let(:color) { "yellow" }
    let(:config) { instance_double(Stoplight::Domain::Config) }

    it "throws halt without locking" do
      expect(storage).not_to receive(:lock)

      expect do
        call
      end.to throw_symbol(:halt, 400)
    end
  end
end
