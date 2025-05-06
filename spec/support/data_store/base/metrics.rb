# frozen_string_literal: true

RSpec.shared_examples "data store metrics" do
  describe "Metadata#last_success_at" do
    let(:request_time) { Time.at(1746119141) }

    context "when the success is recorded" do
      it "returns the time of the success" do
        expect do
          data_store.record_success(config, request_time:)
        end.to change { data_store.get_metadata(config).last_success_at }
          .from(nil)
          .to(request_time)
      end
    end

    context "when the recovery probe success is recorded" do
      it "returns the time of the success" do
        expect do
          data_store.record_recovery_probe_success(config, request_time:)
        end.to change { data_store.get_metadata(config).last_success_at }
          .from(nil)
          .to(request_time)
      end
    end

    context "when an older request is recorded after a newer one" do
      let(:older_request_time) { Time.at(1746110141) }

      before do
        data_store.record_success(config, request_time:)
      end

      it "returns the time of the latest successful request" do
        expect do
          data_store.record_success(config, request_time: older_request_time)
        end.not_to change { data_store.get_metadata(config).last_success_at }
          .from(request_time)
      end
    end

    context "when a newer request is recorded after an older one" do
      let(:older_request_time) { Time.at(1746110141) }

      before do
        data_store.record_success(config, request_time: older_request_time)
      end

      it "returns the time of the latest request" do
        expect do
          data_store.record_success(config, request_time:)
        end.to change { data_store.get_metadata(config).last_success_at }
          .from(older_request_time)
          .to(request_time)
      end
    end

    context "when a newer recovery probe success is recorded after a normal request" do
      let(:recovery_probe_request_time) { Time.at(1746159141) }

      before do
        data_store.record_success(config, request_time:)
      end

      it "returns the time of the latest request" do
        expect do
          data_store.record_recovery_probe_success(config, request_time: recovery_probe_request_time)
        end.to change { data_store.get_metadata(config).last_success_at }
          .from(request_time)
          .to(recovery_probe_request_time)
      end
    end

    context "when a success is recorded after a recovery probe success" do
      let(:recovery_probe_request_time) { Time.at(1746110141) }

      before do
        data_store.record_recovery_probe_success(config, request_time: recovery_probe_request_time)
      end

      it "returns the time of the latest request" do
        expect do
          data_store.record_success(config, request_time:)
        end.to change { data_store.get_metadata(config).last_success_at }
          .from(recovery_probe_request_time)
          .to(request_time)
      end
    end

    context "when a newer recovery probe success is recorded after another recovery probe success" do
      let(:recovery_probe_request_time) { Time.at(1746159141) }

      before do
        data_store.record_recovery_probe_success(config, request_time:)
      end

      it "returns the time of the latest request" do
        expect do
          data_store.record_recovery_probe_success(config, request_time: recovery_probe_request_time)
        end.to change { data_store.get_metadata(config).last_success_at }
          .from(request_time)
          .to(recovery_probe_request_time)
      end
    end

    context "when a newer recovery probe success is recorded after a newer recovery probe success" do
      let(:recovery_probe_request_time) { request_time - 10}

      before do
        data_store.record_recovery_probe_success(config, request_time:)
      end

      it "returns the time of the latest request" do
        expect do
          data_store.record_recovery_probe_success(config, request_time: recovery_probe_request_time)
        end.not_to change { data_store.get_metadata(config).last_success_at }
          .from(request_time)
      end
    end
  end

  describe "Metadata#last_failure_at" do
    let(:failure) { Stoplight::Failure.from_error(error) }
    let(:error) { StandardError.new("Test error") }

    context "when the failure is recorded" do
      it "returns the time of the failure" do
        expect do
          data_store.record_failure(config, failure)
        end.to change { data_store.get_metadata(config).last_failure_at }
          .from(nil)
          .to(failure.time)
      end
    end

    context "when an older failure is recorded after a newer one" do
      let(:older_failure) { Stoplight::Failure.from_error(error, time: Time.now - 1000) }

      before do
        data_store.record_failure(config, failure)
      end

      it "returns the time of the latest failure" do
        expect do
          data_store.record_failure(config, older_failure)
        end.not_to change { data_store.get_metadata(config).last_failure_at }
          .from(failure.time)
      end
    end

    context "when a newer failure is recorded after an older one" do
      let(:older_failure) { Stoplight::Failure.from_error(error, time: Time.now - 1000) }

      before do
        data_store.record_failure(config, older_failure)
      end

      it "returns the time of the latest failure" do
        expect do
          data_store.record_failure(config, failure)
        end.to change { data_store.get_metadata(config).last_failure_at }
          .from(older_failure.time)
          .to(failure.time)
      end
    end

    context "when a newer recovery probe failure is recorded after a failure" do
      let(:recovery_probe_failure) { Stoplight::Failure.from_error(error, time: Time.now + 5000) }

      before do
        data_store.record_failure(config, failure)
      end

      it "returns the time of the latest failure" do
        expect do
          data_store.record_recovery_probe_failure(config, recovery_probe_failure)
        end.to change { data_store.get_metadata(config).last_failure_at }
          .from(failure.time)
          .to(recovery_probe_failure.time)
      end
    end

    context "when a failure is recorded after a recovery probe failure" do
      let(:recovery_probe_failure) { Stoplight::Failure.from_error(error, time: Time.now - 5000) }

      before do
        data_store.record_recovery_probe_failure(config, recovery_probe_failure)
      end

      it "returns the time of the latest failure" do
        expect do
          data_store.record_failure(config, failure)
        end.to change { data_store.get_metadata(config).last_failure_at }
          .from(recovery_probe_failure.time)
          .to(failure.time)
      end
    end
  end

  describe "Metadata#last_failure" do
    let(:failure) { Stoplight::Failure.from_error(error) }
    let(:error) { StandardError.new("Test error") }

    context "when the failure is recorded" do
      it "returns last failure" do
        expect do
          data_store.record_failure(config, failure)
        end.to change { data_store.get_metadata(config).last_failure }
          .from(nil)
          .to(failure)
      end
    end

    context "when an older failure is recorded after a newer one" do
      let(:older_failure) { Stoplight::Failure.from_error(error, time: Time.now - 5000) }

      before do
        data_store.record_failure(config, failure)
      end

      it "returns the latest failure" do
        expect(data_store.get_metadata(config).last_failure).to eq(failure)

        data_store.record_failure(config, older_failure)

        expect(data_store.get_metadata(config).last_failure).to eq(failure)
      end
    end

    context "when a newer failure is recorded after an older one" do
      let(:older_failure) { Stoplight::Failure.from_error(error, time: Time.now - 1000) }

      before do
        data_store.record_failure(config, older_failure)
      end

      it "returns the time of the latest failure" do
        expect(data_store.get_metadata(config).last_failure).to eq(older_failure)

        data_store.record_failure(config, failure)

        expect(data_store.get_metadata(config).last_failure).to eq(failure)
      end
    end

    context "when a newer recovery probe failure is recorded after a failure" do
      let(:recovery_probe_failure) { Stoplight::Failure.from_error(error, time: Time.now + 5000) }

      before do
        data_store.record_failure(config, failure)
      end

      it "returns the time of the latest failure" do
        expect(data_store.get_metadata(config).last_failure).to eq(failure)

        data_store.record_recovery_probe_failure(config, recovery_probe_failure)

        expect(data_store.get_metadata(config).last_failure).to eq(recovery_probe_failure)
      end
    end

    context "when a failure is recorded after a recovery probe failure" do
      let(:recovery_probe_failure) { Stoplight::Failure.from_error(error, time: Time.now - 5000) }

      before do
        data_store.record_recovery_probe_failure(config, recovery_probe_failure)
      end

      it "returns the time of the latest failure" do
        expect(data_store.get_metadata(config).last_failure).to eq(recovery_probe_failure)

        data_store.record_failure(config, failure)

        expect(data_store.get_metadata(config).last_failure).to eq(failure)
      end
    end
  end

  describe "Metadata#success" do
    let(:failure) { Stoplight::Failure.from_error(error) }
    let(:error) { StandardError.new("Test error") }

    context "when the success is recorded" do
      it "returns the the number of successful requests" do
        expect do
          data_store.record_success(config)
        end.to change { data_store.get_metadata(config).successes }.by(1)

        expect do
          data_store.record_success(config)
        end.to change { data_store.get_metadata(config).successes }.by(1)
      end
    end

    context "when a failure is recorded after success" do
      it "returns the the number of successful requests in total" do
        data_store.record_success(config)

        expect do
          data_store.record_failure(config, failure)
          data_store.record_success(config)
          data_store.record_success(config)
        end.to change { data_store.get_metadata(config).successes }.from(1).to(3)
      end
    end

    context "when a success is outside of the running window" do
      let(:window_size) { 5000 }

      it "returns the the number of successful requests within the current window" do
        data_store.record_success(config, request_time: Time.now - window_size - 1)
        data_store.record_success(config)
        data_store.record_success(config)

        expect(data_store.get_metadata(config).successes).to eq(2)
      end
    end
  end

  describe "Metadata#failures" do
    let(:failure) { Stoplight::Failure.from_error(error) }
    let(:error) { StandardError.new("Test error") }

    context "when the failure is recorded" do
      it "returns the the number of failed requests" do
        expect do
          data_store.record_failure(config, failure)
        end.to change { data_store.get_metadata(config).failures }.by(1)

        expect do
          data_store.record_failure(config, failure)
        end.to change { data_store.get_metadata(config).failures }.by(1)
      end
    end

    context "when a success is recorded after failure" do
      it "returns the the number of failed requests in total" do
        data_store.record_failure(config, Stoplight::Failure.from_error(error))

        expect do
          data_store.record_success(config)
          data_store.record_failure(config, Stoplight::Failure.from_error(error))
          data_store.record_failure(config, Stoplight::Failure.from_error(error))
        end.to change { data_store.get_metadata(config).failures }.from(1).to(3)
      end
    end

    context "when a failure is outside of the running window" do
      let(:outdated_failure) { Stoplight::Failure.from_error(error, time: Time.now - window_size - 1) }
      let(:window_size) { 5000 }

      it "returns the the number of successful requests within the current window" do
        data_store.record_failure(config, outdated_failure)
        data_store.record_failure(config, failure)
        data_store.record_failure(config, failure)

        expect(data_store.get_metadata(config).failures).to eq(2)
      end
    end
  end

  describe "Metadata#recovery_probe_successes" do
    let(:failure) { Stoplight::Failure.from_error(error) }
    let(:error) { StandardError.new("Test error") }

    context "when the success is recorded" do
      it "returns the the number of successful requests" do
        expect do
          data_store.record_recovery_probe_success(config)
        end.to change { data_store.get_metadata(config).recovery_probe_successes }.by(1)

        expect do
          data_store.record_recovery_probe_success(config)
        end.to change { data_store.get_metadata(config).recovery_probe_successes }.by(1)
      end
    end

    context "when a failure is recorded after success" do
      it "returns the the number of successful requests in total" do
        data_store.record_recovery_probe_success(config)

        expect do
          data_store.record_recovery_probe_failure(config, failure)
          data_store.record_success(config) # ignored
          data_store.record_recovery_probe_success(config)
          data_store.record_recovery_probe_success(config)
        end.to change { data_store.get_metadata(config).recovery_probe_successes }.from(1).to(3)
      end
    end

    context "when a success is outside of the running window" do
      let(:window_size) { 5000 }

      it "returns the the number of successful requests within the current window" do
        data_store.record_recovery_probe_success(config, request_time: Time.now - window_size - 1)
        data_store.record_recovery_probe_success(config)
        data_store.record_recovery_probe_success(config)

        expect(data_store.get_metadata(config).recovery_probe_successes).to eq(2)
      end
    end
  end

  describe "Metadata#recovery_probe_failures" do
    let(:failure) { Stoplight::Failure.from_error(error) }
    let(:error) { StandardError.new("Test error") }

    context "when the failure is recorded" do
      it "returns the the number of failed requests" do
        expect do
          data_store.record_recovery_probe_failure(config, failure)
        end.to change { data_store.get_metadata(config).recovery_probe_failures }.by(1)

        expect do
          data_store.record_recovery_probe_failure(config, failure)
        end.to change { data_store.get_metadata(config).recovery_probe_failures }.by(1)
      end
    end

    context "when a success is recorded after failure" do
      it "returns the the number of failed requests in total" do
        data_store.record_recovery_probe_failure(config, Stoplight::Failure.from_error(error))

        expect do
          data_store.record_recovery_probe_success(config)
          data_store.record_failure(config, Stoplight::Failure.from_error(error)) # ignored
          data_store.record_recovery_probe_failure(config, Stoplight::Failure.from_error(error))
          data_store.record_recovery_probe_failure(config, Stoplight::Failure.from_error(error))
        end.to change { data_store.get_metadata(config).recovery_probe_failures }.from(1).to(3)
      end
    end

    context "when a failure is outside of the running window" do
      let(:outdated_failure) { Stoplight::Failure.from_error(error, time: Time.now - window_size - 1) }
      let(:window_size) { 5000 }

      it "returns the the number of successful requests within the current window" do
        data_store.record_recovery_probe_failure(config, outdated_failure)
        data_store.record_recovery_probe_failure(config, failure)
        data_store.record_recovery_probe_failure(config, failure)

        expect(data_store.get_metadata(config).recovery_probe_failures).to eq(2)
      end
    end
  end

  describe "Metadata#consecutive_successes" do
    let(:failure) { Stoplight::Failure.from_error(error) }
    let(:error) { StandardError.new("Test error") }

    context "when the success is recorded" do
      it "returns the the number of successful requests" do
        expect do
          data_store.record_success(config)
        end.to change { data_store.get_metadata(config).consecutive_successes }.by(1)

        expect do
          data_store.record_success(config)
        end.to change { data_store.get_metadata(config).consecutive_successes }.by(1)
      end
    end

    context "when a failure is recorded after success" do
      it "returns the the number of successful requests in total" do
        data_store.record_success(config)

        expect do
          data_store.record_failure(config, failure)
          data_store.record_success(config)
          data_store.record_success(config)
        end.to change { data_store.get_metadata(config).consecutive_successes }.from(1).to(2)
      end
    end

    context "when a success is outside of the running window" do
      let(:window_size) { 5000 }

      it "returns the the number of successful requests within the current window" do
        data_store.record_success(config, request_time: Time.now - window_size - 1)
        data_store.record_success(config)
        data_store.record_success(config)

        expect(data_store.get_metadata(config).consecutive_successes).to eq(3)
      end
    end
  end

  describe "Metadata#consecutive_failures" do
    let(:failure) { Stoplight::Failure.from_error(error) }
    let(:error) { StandardError.new("Test error") }

    context "when the failure is recorded" do
      it "returns the the number of failed requests" do
        expect do
          data_store.record_failure(config, failure)
        end.to change { data_store.get_metadata(config).consecutive_failures }.by(1)

        expect do
          data_store.record_failure(config, failure)
        end.to change { data_store.get_metadata(config).consecutive_failures }.by(1)
      end
    end

    context "when a success is recorded after failure" do
      it "returns the the number of failed requests in total" do
        data_store.record_failure(config, Stoplight::Failure.from_error(error))

        expect do
          data_store.record_success(config)
          data_store.record_failure(config, Stoplight::Failure.from_error(error))
          data_store.record_failure(config, Stoplight::Failure.from_error(error))
        end.to change { data_store.get_metadata(config).consecutive_failures }.from(1).to(2)
      end
    end

    context "when a failure is outside of the running window" do
      let(:outdated_failure) { Stoplight::Failure.from_error(error, time: Time.now - window_size - 1) }
      let(:window_size) { 5000 }

      it "returns the the number of successful requests within the current window" do
        data_store.record_failure(config, outdated_failure)
        data_store.record_failure(config, failure)
        data_store.record_failure(config, failure)

        expect(data_store.get_metadata(config).consecutive_failures).to eq(3)
      end
    end
  end

  describe "#record_failure" do
    let(:failure) { Stoplight::Failure.from_error(error) }
    let(:error) { StandardError.new("Test error") }
    let(:failure_time) { failure.time }

    context "when the failure is recorded" do
      it "returns the the number of failed requests" do
        expect do
          data_store.record_failure(config, failure)
        end.to change { data_store.get_metadata(config) }
          .from(have_attributes(failures: 0, consecutive_failures: 0, last_failure_at: nil, last_failure: nil))
          .to(have_attributes(failures: 1, consecutive_failures: 1, last_failure_at: failure_time, last_failure: failure))
      end
    end

    context "when a success is recorded after failure" do
      before do
        data_store.record_failure(config, Stoplight::Failure.from_error(error))
      end

      it "returns the the number of failed requests in total" do
        expect do
          data_store.record_success(config)
          data_store.record_failure(config, Stoplight::Failure.from_error(error))
          data_store.record_failure(config, Stoplight::Failure.from_error(error))
        end.to change { data_store.get_metadata(config) }
          .from(have_attributes(failures: 1, successes: 0, consecutive_failures: 1))
          .to(have_attributes(failures: 3, successes: 1, consecutive_failures: 2))
      end
    end

    context "when a failure is outside of the running window" do
      let(:outdated_failure) { Stoplight::Failure.from_error(error, time: Time.now - window_size - 1) }
      let(:window_size) { 5000 }

      it "returns the the number of successful requests within the current window" do
        data_store.record_failure(config, outdated_failure)
        data_store.record_failure(config, failure)
        data_store.record_failure(config, failure)

        expect(data_store.get_metadata(config)).to have_attributes(
          failures: 2,
          consecutive_failures: 3
        )
      end
    end
  end
end
