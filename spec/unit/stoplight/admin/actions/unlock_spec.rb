# frozen_string_literal: true

RSpec.describe Stoplight::Admin::Actions::Unlock do
  subject(:call) { action.call(light_id:) }

  let(:action) { described_class.new(config_registry:, storage:) }
  let(:config_registry) { instance_double(Stoplight::Admin::ConfigRegistry) }
  let(:storage) { instance_double(Stoplight::Wiring::System::Storage) }
  let(:light_id) { SecureRandom.uuid }

  before do
    allow(config_registry).to receive(:find_by_id).with(light_id).and_return(config)
  end

  context "when existing light id is provided" do
    let(:config) { instance_double(Stoplight::Domain::Config) }

    it "unlocks this light" do
      expect(storage).to receive(:unlock).with(config)

      call
    end
  end

  context "when light does not exists" do
    let(:config) { nil }

    it "throws halt" do
      expect(storage).not_to receive(:unlock)

      expect do
        call
      end.to throw_symbol(:halt, 404)
    end
  end
end
