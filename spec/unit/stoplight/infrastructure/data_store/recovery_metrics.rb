# frozen_string_literal: true

RSpec.shared_examples "Stoplight::Domain::DataStore#get_recovery_metrics" do
  let(:error) { StandardError.new("Test error") }
  # Redis serialization (Time -> Float -> Redis -> Float -> Time) introduces
  # sub-microsecond precision loss. This is expected and acceptable.
  let(:rounding_error) { 0.000001 } # ~1 microsecond tolerance

  def get_recovery_metrics
    data_store.get_recovery_metrics(config)
  end

  def record_failure(error)
    data_store.record_failure(config, error)
  end

  def record_success
    data_store.record_success(config)
  end

  def record_recovery_probe_failure(error)
    data_store.record_recovery_probe_failure(config, error)
  end

  def record_recovery_probe_success
    data_store.record_recovery_probe_success(config)
  end

  describe "#last_success_at" do
    let(:last_success_time) { Time.now + 30 }

    specify "when success tracked after recovery probe success tracked" do
      record_recovery_probe_success

      expect do
        Timecop.freeze(last_success_time) do
          record_success
        end
      end.to change { get_recovery_metrics.last_success_at }.to(be_within(rounding_error).of(last_success_time))
    end

    specify "when recovery probe success tracked after success" do
      record_success

      expect do
        Timecop.freeze(last_success_time) do
          record_recovery_probe_success
        end
      end.to change { get_recovery_metrics.last_success_at }.to(be_within(rounding_error).of(last_success_time))
    end
  end

  describe "#last_error_at" do
    let(:last_error_time) { Time.now + 30 }

    specify "when failure tracked after recovery probe failure tracked" do
      record_recovery_probe_failure(error)

      expect do
        Timecop.freeze(last_error_time) do
          record_failure(error)
        end
      end.to change { get_recovery_metrics.last_error_at }.to(be_within(rounding_error).of(last_error_time))
    end

    specify "when recovery probe failure tracked after failure" do
      record_failure(error)

      expect do
        Timecop.freeze(last_error_time) do
          record_recovery_probe_failure(error)
        end
      end.to change { get_recovery_metrics.last_error_at }.to(be_within(rounding_error).of(last_error_time))
    end
  end

  describe "#last_error" do
    let(:another_error) { KeyError.new("key not found: :boom") }

    specify "when failure tracked after recovery probe failure tracked" do
      expect { record_recovery_probe_failure(error) }.to change { get_recovery_metrics.last_error&.error_message }.to eq(error.message)
      expect { record_failure(another_error) }.to change { get_recovery_metrics.last_error.error_message }.to eq(another_error.message)
    end

    specify "when recovery probe failure tracked after failure" do
      expect { record_failure(error) }.to change { get_recovery_metrics.last_error&.error_message }.to eq(error.message)
      expect { record_recovery_probe_failure(another_error) }.to change { get_recovery_metrics.last_error.error_message }.to eq(another_error.message)
    end
  end

  describe "#successes" do
    it "does not increment when a success is recorder" do
      expect { record_success }.not_to change { get_recovery_metrics.successes }

      expect { record_recovery_probe_failure(error) }.not_to change { get_recovery_metrics.successes }
      expect { record_failure(error) }.not_to change { get_recovery_metrics.successes }
    end

    it "increments when a record_recovery_probe_success is recorder" do
      expect { record_recovery_probe_success }.to change { get_recovery_metrics.successes }.by(1)
    end

    it "does not count a recovery probe success outside of recovery window" do
      Timecop.freeze(Time.now - cool_off_time - 10) do
        record_recovery_probe_success
      end

      expect { record_recovery_probe_success }.to change { get_recovery_metrics.successes }.from(0).to(1)
    end
  end

  describe "#errors" do
    it "does not increment when a failure is recorder" do
      expect { record_failure(error) }.not_to change { get_recovery_metrics.errors }

      expect { record_recovery_probe_success }.not_to change { get_recovery_metrics.errors }
      expect { record_success }.not_to change { get_recovery_metrics.errors }
    end

    it "increments when a record_recovery_probe_failure is recorder" do
      expect { record_recovery_probe_failure(error) }.to change { get_recovery_metrics.errors }.by(1)
    end

    xit "does not count a failure outside of recovery window" do
      Timecop.freeze(Time.now - cool_off_time - 10) do
        record_failure(error)
      end

      expect { record_failure(error) }.to change { get_recovery_metrics.errors }.from(0).to(1)
    end
  end

  describe "#consecutive_successes" do
    it "resets when a failure is recorded after success" do
      expect { record_success }.to change { get_recovery_metrics.total_consecutive_successes }.by(1)
      expect { record_failure(error) }.to change { get_recovery_metrics.total_consecutive_successes }.to(0)
    end

    it "increments when the consecutive successes" do
      expect { record_success }.to change { get_recovery_metrics.total_consecutive_successes }.by(1)
      expect { record_recovery_probe_success }.to change { get_recovery_metrics.total_consecutive_successes }.by(1)
    end

    it "resets when a recovery probe failure is recorded after success" do
      expect { record_success }.to change { get_recovery_metrics.total_consecutive_successes }.by(1)
      expect { record_recovery_probe_failure(error) }.to change { get_recovery_metrics.total_consecutive_successes }.to(0)
    end

    it "resets when a failure is recorded after recovery probe success" do
      expect { record_recovery_probe_success }.to change { get_recovery_metrics.total_consecutive_successes }.by(1)
      expect { record_failure(error) }.to change { get_recovery_metrics.total_consecutive_successes }.to(0)
    end

    it "resets when a recovery probe failure is recorded after recovery probe success" do
      expect { record_recovery_probe_success }.to change { get_recovery_metrics.total_consecutive_successes }.by(1)
      expect { record_recovery_probe_failure(error) }.to change { get_recovery_metrics.total_consecutive_successes }.to(0)
    end

    context "when a success is outside of the recovery window" do
      let(:cool_off_time) { 5000 }

      before do
        Timecop.freeze(Time.now - cool_off_time - 10) do
          record_success
        end
      end

      it "counts consecutive successes outside of the window too" do
        record_success

        expect(get_recovery_metrics.total_consecutive_successes).to eq(2)
      end
    end

    context "when a recovery probe success is outside of the recovery window" do
      let(:cool_off_time) { 5000 }

      before do
        Timecop.freeze(Time.now - cool_off_time - 10) do
          record_recovery_probe_success
        end
      end

      it "counts consecutive errors outside of the recovery window too" do
        record_recovery_probe_success

        expect(get_recovery_metrics.total_consecutive_successes).to eq(2)
      end
    end
  end

  describe "Metrics#consecutive_errors" do
    it "resets when a success is recorded after failure" do
      expect { record_failure(error) }.to change { get_recovery_metrics.total_consecutive_errors }.by(1)
      expect { record_success }.to change { get_recovery_metrics.total_consecutive_errors }.to(0)
    end

    it "increments when the consecutive errors" do
      expect { record_failure(error) }.to change { get_recovery_metrics.total_consecutive_errors }.by(1)
      expect { record_recovery_probe_failure(error) }.to change { get_recovery_metrics.total_consecutive_errors }.by(1)
    end

    it "resets when a recovery probe success is recorded after failure" do
      expect { record_failure(error) }.to change { get_recovery_metrics.total_consecutive_errors }.by(1)
      expect { record_recovery_probe_success }.to change { get_recovery_metrics.total_consecutive_errors }.to(0)
    end

    it "resets when a success is recorded after recovery probe failure" do
      expect { record_recovery_probe_failure(error) }.to change { get_recovery_metrics.total_consecutive_errors }.by(1)
      expect { record_success }.to change { get_recovery_metrics.total_consecutive_errors }.to(0)
    end

    it "resets when a recovery probe success is recorded after recovery probe failure" do
      expect { record_recovery_probe_failure(error) }.to change { get_recovery_metrics.total_consecutive_errors }.by(1)
      expect { record_recovery_probe_success }.to change { get_recovery_metrics.total_consecutive_errors }.to(0)
    end

    context "when a failure is outside of the recovery window" do
      let(:cool_off_time) { 5000 }

      before do
        Timecop.freeze(Time.now - cool_off_time - 10) do
          record_failure(error)
        end
      end

      it "counts consecutive errors outside of the recovery window too" do
        record_failure(error)

        expect(get_recovery_metrics.total_consecutive_errors).to eq(2)
      end
    end

    context "when a recovery probe failure is outside of the recovery window" do
      let(:cool_off_time) { 5000 }

      before do
        Timecop.freeze(Time.now - cool_off_time - 10) do
          record_recovery_probe_failure(error)
        end
      end

      it "counts consecutive errors outside of the window too" do
        record_failure(error)

        expect(get_recovery_metrics.total_consecutive_errors).to eq(2)
      end
    end
  end
end
