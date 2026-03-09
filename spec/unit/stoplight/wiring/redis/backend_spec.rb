# frozen_string_literal: true

require_relative "../data_store_backend"

RSpec.describe Stoplight::Wiring::Redis::Backend, :redis do
  it_behaves_like Stoplight::Wiring::DataStoreBackend do
    let(:backend) do
      described_class.new(redis:, scripting:, key_space:, clock:, config:, error_notifier:, failover_light:)
    end

    let(:clock) { instance_double(NullClock) }
    let(:scripting) { instance_double(Stoplight::Infrastructure::Redis::Storage::Scripting) }
    let(:key_space) do
      Stoplight::Infrastructure::Redis::Storage::KeySpace.new(
        system_id: SecureRandom.uuid,
        light_id: SecureRandom.uuid
      )
    end
    let(:error_notifier) { ->(e) { warn e } }
    let(:failover_light) { instance_double(Stoplight::Domain::Light) }
  end
end
