# frozen_string_literal: true

require_relative "recovery_metrics"
require_relative "metrics"

RSpec.describe Stoplight::Infrastructure::DataStore::Memory do
  let(:data_store) { described_class.new }
  let(:config) { Stoplight::Domain::Config.empty.with(name:, window_size:, cool_off_time:) }
  let(:name) { ("a".."z").to_a.shuffle.join }
  let(:cool_off_time) { 60 }
  let(:window_size) { 60 }

  it_behaves_like "Stoplight::Domain::DataStore"
  it_behaves_like "Stoplight::Domain::DataStore#get_metrics"
  it_behaves_like "Stoplight::Domain::DataStore#get_recovery_metrics"
  it_behaves_like "Stoplight::Domain::DataStore#names"
  it_behaves_like "Stoplight::Domain::DataStore#set_state"
  it_behaves_like "Stoplight::Domain::DataStore#transition_to_color"

  describe "#with_recovery_lock" do
    let(:recovery_lock_factory) { described_class::RecoveryLockFactory.new }

    before do
      data_store.recovery_lock_factory = recovery_lock_factory
    end

    it "passes control to recovery lock" do
      expect do |recovery|
        data_store.with_recovery_lock(config, &recovery)
      end.to yield_with_args(data_store)
    end
  end
end
