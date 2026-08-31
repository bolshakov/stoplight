# frozen_string_literal: true

require_relative "metrics_snapshot"

RSpec.shared_examples "a window metrics snapshot" do
  it_behaves_like "a metrics snapshot" do
    describe "#consecutive_successes" do
      context "when a success is outside of the running window" do
        let(:window_size) { 5000 }

        before do
          Timecop.freeze(-window_size - 10) do
            record_success
          end
        end

        it "counts consecutive successes outside of the window too" do
          record_success

          expect(metrics_snapshot.consecutive_successes).to eq(1)
        end
      end
    end

    describe "#consecutive_errors" do
      context "when a failure is outside of the running window" do
        let(:window_size) { 5000 }

        before do
          Timecop.freeze(-window_size - 10) do
            record_failure(error)
          end
        end

        it "counts consecutive errors outside of the window too" do
          record_failure(error)

          expect(metrics_snapshot.consecutive_errors).to eq(1)
        end
      end
    end

    describe "#successes" do
      it "increments when a success is recorded" do
        expect { record_success }.to change { metrics_snapshot.successes }.by(1)
      end

      it "does not reset when a failure is recorded after a success" do
        record_success

        expect { record_failure(error) }.not_to change { metrics_snapshot.successes }
      end

      it "accumulates multiple successes" do
        expect { record_success }.to change { metrics_snapshot.successes }.by(1)
        expect { record_success }.to change { metrics_snapshot.successes }.by(1)
      end
    end

    describe "#errors" do
      it "increments when a failure is recorded" do
        expect { record_failure(error) }.to change { metrics_snapshot.errors }.by(1)
      end

      it "does not reset when a success is recorded after a failure" do
        record_failure(error)

        expect { record_success }.not_to change { metrics_snapshot.errors }
      end

      it "accumulates multiple failures" do
        expect { record_failure(error) }.to change { metrics_snapshot.errors }.by(1)
        expect { record_failure(error) }.to change { metrics_snapshot.errors }.by(1)
      end
    end

    describe "window boundary" do
      context "when a success happened exactly window_size seconds ago" do
        let(:window_size) { 300 }

        it "excludes it from the count" do
          Timecop.freeze(Time.now) do
            record_success

            Timecop.freeze(window_size) do
              expect(metrics_snapshot.successes).to eq(0)
            end
          end
        end
      end

      context "when a failure happened exactly window_size seconds ago" do
        let(:window_size) { 300 }

        it "excludes it from the count" do
          Timecop.freeze(Time.now) do
            record_failure(error)

            Timecop.freeze(window_size) do
              expect(metrics_snapshot.errors).to eq(0)
            end
          end
        end
      end
    end

    describe "eviction" do
      context "when many buckets have gone stale before the next write" do
        let(:window_size) { 4200 }
        let(:bucket_count) { window_size }

        it "evicts the whole backlog without raising, keeping successes correct" do
          Timecop.freeze(Time.now) do
            bucket_count.times { |second| Timecop.freeze(second) { record_success } }

            Timecop.freeze(bucket_count + window_size + 10) do
              expect { record_success }.not_to raise_error

              expect(metrics_snapshot.successes).to eq(1)
            end
          end
        end

        it "evicts the whole backlog without raising, keeping errors correct" do
          Timecop.freeze(Time.now) do
            bucket_count.times { |second| Timecop.freeze(second) { record_failure(error) } }

            Timecop.freeze(bucket_count + window_size + 10) do
              expect { record_failure(error) }.not_to raise_error

              expect(metrics_snapshot.errors).to eq(1)
            end
          end
        end

        it "subtracts successes and failures independently when buckets mix both" do
          Timecop.freeze(Time.now) do
            bucket_count.times do |second|
              Timecop.freeze(second) { second.even? ? record_success : record_failure(error) }
            end

            Timecop.freeze(bucket_count + window_size + 10) do
              record_success

              expect(metrics_snapshot.successes).to eq(1)
              expect(metrics_snapshot.errors).to eq(0)
            end
          end
        end
      end
    end
  end
end
