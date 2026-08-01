# frozen_string_literal: true

require_relative "../../data_store/recovery_metrics"

RSpec.describe Stoplight::Infrastructure::Redis::Storage::RecoveryMetrics, :redis do
  subject(:metrics_store) { described_class.new(scripting:, redis:, key_space:, clock:) }

  let(:clock) { Stoplight::Infrastructure::SystemClock.new }
  let(:key_space) { Stoplight::DataStore::Redis.key_space.join(SecureRandom.uuid) }
  let(:scripting) { Stoplight::Infrastructure::Redis::Storage::Scripting.new(redis:) }

  it_behaves_like "Stoplight::Domain::DataStore#get_recovery_metrics" do
    def get_metrics = metrics_store.metrics_snapshot
    def record_failure(error) = metrics_store.record_failure(error)
    def record_success = metrics_store.record_success
  end
end
