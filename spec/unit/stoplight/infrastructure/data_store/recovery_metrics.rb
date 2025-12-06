# frozen_string_literal: true

RSpec.shared_examples "Stoplight::Domain::DataStore#get_recovery_metrics" do
  let(:error) { StandardError.new("Test error") }
  # Redis serialization (Time -> Float -> Redis -> Float -> Time) introduces
  # sub-microsecond precision loss. This is expected and acceptable.
  let(:rounding_error) { 0.000001 } # ~1 microsecond tolerance

  def get_metrics
    data_store.get_recovery_metrics(config)
  end

  def record_failure(error)
    data_store.record_recovery_probe_failure(config, error)
  end

  def record_success
    data_store.record_recovery_probe_success(config)
  end

  describe "#last_success_at" do
    let(:last_success_time) { Time.now + 30 }

    specify "when success tracked after another success" do
      record_success

      expect do
        Timecop.freeze(last_success_time) do
          record_success
        end
      end.to change { get_metrics.last_success_at }.to(be_within(rounding_error).of(last_success_time))
    end

    specify "when first success tracked" do
      expect do
        Timecop.freeze(last_success_time) do
          record_success
        end
      end.to change { get_metrics.last_success_at }.from(nil).to(be_within(rounding_error).of(last_success_time))
    end
  end

  describe "#last_error_at" do
    let(:last_error_time) { Time.now + 30 }

    specify "when failure tracked after another failure" do
      record_failure(error)

      expect do
        Timecop.freeze(last_error_time) do
          record_failure(error)
        end
      end.to change { get_metrics.last_error_at }.to(be_within(rounding_error).of(last_error_time))
    end

    specify "when first failure tracked" do
      expect do
        Timecop.freeze(last_error_time) do
          record_failure(error)
        end
      end.to change { get_metrics.last_error_at }.to(be_within(rounding_error).of(last_error_time))
    end
  end

  describe "#last_error" do
    let(:another_error) { KeyError.new("key not found: :boom") }

    specify "when failure tracked after another failure" do
      expect { record_failure(error) }.to change { get_metrics.last_error&.error_message }.from(nil).to(error.message)
      expect { record_failure(another_error) }.to change { get_metrics.last_error.error_message }.from(error.message).to(another_error.message)
    end
  end

  describe "#consecutive_successes" do
    it "resets when a failure is recorded after success" do
      expect { record_success }.to change { get_metrics.consecutive_successes }.by(1)
      expect { record_failure(error) }.to change { get_metrics.consecutive_successes }.to(0)
    end

    it "increments when the consecutive successes" do
      expect { record_success }.to change { get_metrics.consecutive_successes }.by(1)
      expect { record_success }.to change { get_metrics.consecutive_successes }.by(1)
    end
  end

  describe "#consecutive_errors" do
    it "resets when a success is recorded after failure" do
      expect { record_failure(error) }.to change { get_metrics.consecutive_errors }.by(1)
      expect { record_success }.to change { get_metrics.consecutive_errors }.to(0)
    end

    it "increments when the consecutive errors" do
      expect { record_failure(error) }.to change { get_metrics.consecutive_errors }.by(1)
      expect { record_failure(error) }.to change { get_metrics.consecutive_errors }.by(1)
    end
  end
end
