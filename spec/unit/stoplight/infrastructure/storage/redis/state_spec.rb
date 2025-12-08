# frozen_string_literal: true

RSpec.describe Stoplight::Infrastructure::Storage::Redis::State, :redis do
  shared_examples Stoplight::Infrastructure::Storage::Redis::State do
    subject(:storage) { described_class.new(clock:, redis: connection, scripting:, key_space:, cool_off_time:) }

    let(:scripting) { Stoplight::Infrastructure::DataStore::Redis::Scripting.new(redis:) }
    let(:key_space) { Stoplight::Infrastructure::Storage::Redis::KeySpace.build(light_name:, system_name:) }
    let(:clock) { Stoplight::Infrastructure::SystemClock.new }

    let(:light_name) { SecureRandom.uuid }
    let(:system_name) { SecureRandom.uuid }
    let(:cool_off_time) { 60 }

    def state_snapshot = storage.state_snapshot
    def clear = storage.clear

    it_behaves_like "Stoplight::Domain::DataStore#set_state" do
      def set_state(state) = storage.set_state(state)
    end

    it_behaves_like "Stoplight::Domain::DataStore#transition_to_color" do
      def transition_to_color(color) = storage.transition_to_color(color)
    end
  end

  it_behaves_like Stoplight::Infrastructure::Storage::Redis::State do
    let(:connection) { redis }
  end

  it_behaves_like Stoplight::Infrastructure::Storage::Redis::State do
    let(:connection) { ConnectionPool.new(size: 1, timeout: 5, &redis_client_factory) }
  end
end
