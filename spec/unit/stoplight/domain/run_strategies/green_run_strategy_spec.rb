# frozen_string_literal: true

RSpec.describe Stoplight::Domain::Strategies::GreenRunStrategy do
  subject(:strategy) do
    described_class.new(
      config:,
      request_tracker:
    )
  end

  let(:config) { instance_double(Stoplight::Domain::Config) }
  let(:request_tracker) { instance_double(Stoplight::Domain::Tracker::Request) }

  context "when code executes successfully" do
    subject(:result) { strategy.execute(nil, state_snapshot: nil, &code) }

    let(:code) { -> { "Success" } }

    it "returns result" do
      expect(request_tracker).to receive(:record_success)

      expect(result).to eq("Success")
    end
  end

  context "when code fails" do
    subject(:result) { strategy.execute(fallback, state_snapshot: nil, &code) }

    let(:error) { StandardError.new("Test error") }
    let(:code) { -> { raise error } }
    let(:metadata) { instance_double(Stoplight::Domain::Metadata) }

    before do
      allow(config).to receive(:track_error?).and_return(track_error)
    end

    context "when error is tracked" do
      let(:track_error) { true }

      context "when fallback is not provided" do
        let(:fallback) { nil }

        it "records failure, notify and raises the error" do
          expect(request_tracker).to receive(:record_failure).with(error)

          expect { result }.to raise_error(error)
        end
      end

      context "when fallback is provided" do
        let(:fallback) do
          ->(error) {
            @error = error
            "Fallback"
          }
        end

        it "records failure, notify and returns the fallback" do
          expect(request_tracker).to receive(:record_failure).with(error)

          expect(result).to eq("Fallback")
          expect(@error).to eq(error)
        end
      end
    end

    context "when error is not tracked" do
      let(:fallback) { nil }
      let(:track_error) { false }

      it "records success and raises the error" do
        expect(request_tracker).to receive(:record_success)

        expect { result }.to raise_error(StandardError, "Test error")
      end
    end
  end

  describe "#==" do
    context "with the same arguments" do
      let(:other) { described_class.new(config:, request_tracker:) }

      it { is_expected.to eq(other) }
    end

    context "with different config" do
      let(:other) { described_class.new(config: other_config, request_tracker:) }
      let(:other_config) { instance_double(Stoplight::Domain::Config) }

      it { is_expected.not_to eq(other) }
    end

    context "with different request recorder" do
      let(:other) { described_class.new(config:, request_tracker: other_request_tracker) }
      let(:other_request_tracker) { instance_double(Stoplight::Domain::Tracker::Request) }

      it { is_expected.not_to eq(other) }
    end
  end
end
