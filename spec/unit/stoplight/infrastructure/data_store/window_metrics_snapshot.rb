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
    end

    describe "eviction" do
      context "when many buckets have gone stale before the next write" do
        let(:window_size) { 4200 }
        let(:bucket_count) { window_size }

        it "evicts the whole backlog without raising, keeping totals correct" do
          Timecop.freeze(Time.now) do
            bucket_count.times { |second| Timecop.freeze(second) { record_success } }

            expect {
              Timecop.freeze(bucket_count + window_size + 10) { record_success }
            }.not_to raise_error

            expect(metrics_snapshot.successes).to eq(1)
          end
        end
      end
    end
  end
end
