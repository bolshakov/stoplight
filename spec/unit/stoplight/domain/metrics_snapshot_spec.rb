# frozen_string_literal: true

RSpec.describe Stoplight::Domain::MetricsSnapshot do
  def build_metrics(**attributes)
    Stoplight::Domain::MetricsSnapshot.new(
      successes: nil,
      errors: nil,
      consecutive_errors: nil,
      consecutive_successes: nil,
      last_error: nil,
      last_success_at: nil,
      **attributes
    )
  end

  describe "#error_rate" do
    context "when there are no successes or errors" do
      let(:metrics) { build_metrics(successes: 0, errors: 0) }

      it "returns 0" do
        expect(metrics.error_rate).to eq(0)
      end
    end

    context "when there are successes and errors" do
      let(:metrics) { build_metrics(successes: 10, errors: 5) }

      it "returns the error rate" do
        expect(metrics.error_rate).to eq(5.fdiv(15))
      end
    end
  end
end
