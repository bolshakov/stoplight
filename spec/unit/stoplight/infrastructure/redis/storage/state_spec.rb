# frozen_string_literal: true

RSpec.describe Stoplight::Infrastructure::Redis::Storage::State, :redis do
  shared_examples Stoplight::Infrastructure::Redis::Storage::State do
    subject(:storage) { described_class.new(clock:, redis: connection, scripting:, key_space:, cool_off_time:) }

    let(:scripting) { Stoplight::Infrastructure::Redis::Storage::Scripting.new(redis:) }
    let(:key_space) { Stoplight::DataStore::Redis.key_space.join(SecureRandom.uuid) }
    let(:clock) { Stoplight::Infrastructure::SystemClock.new }

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

  it_behaves_like Stoplight::Infrastructure::Redis::Storage::State do
    let(:connection) { redis }
  end

  it_behaves_like Stoplight::Infrastructure::Redis::Storage::State do
    let(:connection) { ConnectionPool.new(size: 1, timeout: 5, &redis_client_factory) }
  end
end
