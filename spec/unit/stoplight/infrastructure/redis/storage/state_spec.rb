# frozen_string_literal: true

RSpec.describe Stoplight::Infrastructure::Redis::Storage::State, :redis do
  shared_examples Stoplight::Infrastructure::Redis::Storage::State do
    subject(:storage) { described_class.new(clock:, redis: connection, scripting:, key_space:, cool_off_time:) }

    let(:scripting) do
      Stoplight::Infrastructure::Redis::Storage::Scripting.new(redis:, scripts_path: Stoplight::TimeTravel.scripts_path)
    end
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

    context "when the client clock is skewed against Redis" do
      let(:redis_time) { Time.at(Time.now.to_i) }
      let(:clock) { instance_double(NullClock) }

      before do
        allow(clock).to receive(:current_time) { Time.now + client_skew }
        allow(clock).to receive(:at) { |timestamp| Time.at(timestamp) }
      end

      shared_examples "uses redis server time" do
        it "schedules recovery based on Redis server time" do
          Stoplight::TimeTravel.freeze(redis_time) do
            storage.transition_to_color(Stoplight::Color::RED)
          end

          expect(storage.state_snapshot).to have_attributes(
            breached_at: redis_time,
            recovery_scheduled_after: redis_time + cool_off_time
          )
        end

        it "stamps the snapshot with Redis time" do
          Stoplight::TimeTravel.freeze(redis_time) do
            expect(storage.state_snapshot.time).to eq(redis_time)
          end
        end
      end

      shared_examples "respects cool-off time threshold" do
        before do
          Stoplight::TimeTravel.freeze(redis_time) do
            storage.transition_to_color(Stoplight::Color::RED)
          end
        end

        it "stays red until the cool-off elapses on Redis" do
          Stoplight::TimeTravel.freeze(redis_time + cool_off_time - 1) do
            expect(storage.state_snapshot.color).to eq(Stoplight::Color::RED)
          end
        end

        it "turns yellow once the cool-off elapses on Redis" do
          Stoplight::TimeTravel.freeze(redis_time + cool_off_time + 1) do
            expect(storage.state_snapshot.color).to eq(Stoplight::Color::YELLOW)
          end
        end
      end

      context "when the client clock runs ahead of Redis" do
        let(:client_skew) { 3600 }

        include_examples "uses redis server time"
        include_examples "respects cool-off time threshold"
      end

      context "when the client clock runs behind Redis" do
        let(:client_skew) { -3600 }

        include_examples "uses redis server time"
        include_examples "respects cool-off time threshold"
      end
    end
  end

  it_behaves_like Stoplight::Infrastructure::Redis::Storage::State do
    let(:connection) { redis }
  end

  it_behaves_like Stoplight::Infrastructure::Redis::Storage::State do
    let(:connection) { ConnectionPool.new(size: 1, timeout: 5, &redis_client_factory) }
  end
end
