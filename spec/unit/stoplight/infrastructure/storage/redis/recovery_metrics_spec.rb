# frozen_string_literal: true

require_relative "../../data_store/recovery_metrics"

RSpec.describe Stoplight::Infrastructure::Storage::Redis::RecoveryMetrics, :redis do
  subject(:metrics_store) { described_class.new(scripting:, redis:, key_space:, clock:) }

  let(:clock) { Stoplight::Infrastructure::SystemClock.new }
  let(:key_space) { Stoplight::Infrastructure::Storage::Redis::KeySpace.build(light_name:, system_name:) }
  let(:scripting) { Stoplight::Infrastructure::Storage::Redis::Scripting.new(redis:) }

  let(:light_name) { SecureRandom.uuid }
  let(:system_name) { SecureRandom.uuid }

  it_behaves_like "Stoplight::Domain::DataStore#get_recovery_metrics" do
    def get_metrics = metrics_store.metrics_snapshot
    def record_failure(error) = metrics_store.record_failure(error)
    def record_success = metrics_store.record_success
  end
end
