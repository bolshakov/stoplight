# frozen_string_literal: true

RSpec.describe Stoplight::Admin::ConfigRegistry, :redis do
  subject(:repository) { described_class.new(registry:, system_config: system.config) }

  let(:system) { Stoplight.register_system(SecureRandom.uuid, data_store: data_store_config) }
  let(:registry) do
    Stoplight::Infrastructure::Redis::Storage::Registry.new(
      redis:,
      key_space: data_store_config.key_space.join(system.config.id),
      clock: Stoplight::Infrastructure::SystemClock.new,
      config_serializer: Stoplight::Infrastructure::ConfigSerializer
    )
  end
  let(:data_store_config) { Stoplight::DataStore::Redis.new(redis) }

  describe "#find_by_id" do
    subject(:config) { repository.find_by_id(id) }

    let(:name) { "lights-repository" }
    let(:id) { Stoplight::Domain::Id.for(name) }

    before { system.register(name) }

    context "when the light exists" do
      it "loads the light config" do
        expect(config).to have_attributes(name:)
      end
    end

    context "when the light was never registered on this system" do
      let(:id) { SecureRandom.uuid }

      it "returns nil" do
        expect(config).to be_nil
      end
    end
  end
end
