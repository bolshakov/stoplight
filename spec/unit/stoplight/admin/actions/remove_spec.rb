# frozen_string_literal: true

RSpec.describe Stoplight::Admin::Actions::Remove do
  subject(:call) { action.call(light_id:) }

  let(:action) { described_class.new(config_registry:, storage:, registry:) }
  let(:config_registry) { instance_double(Stoplight::Admin::ConfigRegistry) }
  let(:storage) { instance_double(Stoplight::Wiring::System::Storage) }
  let(:registry) { instance_double(Stoplight::Infrastructure::Redis::Storage::Registry) }
  let(:light_id) { SecureRandom.uuid }

  before do
    allow(config_registry).to receive(:find_by_id).with(light_id).and_return(config)
  end

  context "when existing light removed" do
    let(:config) { instance_double(Stoplight::Domain::Config, id: light_id) }

    it "removes this light" do
      expect(storage).to receive(:delete).with(config)
      expect(registry).to receive(:unregister).with(light_id)

      call
    end
  end

  context "when non-existing light removed" do
    let(:config) { nil }

    it "removes this light" do
      expect(storage).not_to receive(:delete)
      expect(registry).not_to receive(:unregister)

      expect { call }.to throw_symbol(:halt, 404)
    end
  end
end
