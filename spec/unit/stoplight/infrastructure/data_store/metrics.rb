# frozen_string_literal: true

require_relative "window_metrics_snapshot"

RSpec.shared_examples "Stoplight::Domain::DataStore#get_metrics" do
  it_behaves_like "a window metrics snapshot" do
    def metrics_snapshot = data_store.get_metrics(config)
    def record_success = data_store.record_success(config)
    def record_failure(error) = data_store.record_failure(config, error)
  end
end
