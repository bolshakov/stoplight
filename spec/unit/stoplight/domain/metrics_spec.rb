# frozen_string_literal: true

RSpec.describe Stoplight::Domain::Metrics do
  def build_metrics(**attributes)
    Stoplight::Domain::Metrics.new(
      successes: nil,
      errors: nil,
      total_consecutive_errors: nil,
      total_consecutive_successes: nil,
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

  describe "#consecutive_errors" do
    subject(:consecutive_errors) { metrics.consecutive_errors }

    context "when there are no errors or total consecutive errors" do
      let(:metrics) { build_metrics(errors: 0, total_consecutive_errors: 0) }

      it { is_expected.to eq(0) }
    end

    context "when there are more total consecutive errors than errors" do
      let(:metrics) { build_metrics(errors: 1, total_consecutive_errors: 4) }

      it { is_expected.to eq(1) }
    end

    context "when there are no errors" do
      let(:metrics) { build_metrics(errors: 0, total_consecutive_errors: 4) }

      it { is_expected.to eq(0) }
    end
  end

  describe "#consecutive_successes" do
    subject(:consecutive_successes) { metrics.consecutive_successes }

    context "when there are no successes or total consecutive successes" do
      let(:metrics) { build_metrics(successes: 0, total_consecutive_successes: 0) }

      it { is_expected.to eq(0) }
    end

    context "when there are more total consecutive successes than successes" do
      let(:metrics) { build_metrics(successes: 1, total_consecutive_successes: 4) }

      it { is_expected.to eq(1) }
    end

    context "when there are no successes" do
      let(:metrics) { build_metrics(successes: 0, total_consecutive_successes: 4) }

      it { is_expected.to eq(0) }
    end
  end
end
