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
  end
end
