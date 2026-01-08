# frozen_string_literal: true

RSpec.describe Stoplight::Infrastructure::Notifier::FailSafe do
  describe "#notify" do
    subject(:fail_safe_notifier) { described_class.new(notifier:, error_notifier:) }

    let(:notifier) { instance_double(NullNotifier) }
    let(:config) { instance_double(Stoplight::Domain::Config) }
    let(:error_notifier) { instance_double(Proc) }
    let(:from_color) { "green" }
    let(:to_color) { "red" }
    let(:error) { StandardError.new("test error") }

    context "when notification succeeds" do
      it "delegates the notification to the wrapped notifier" do
        allow(notifier).to receive(:notify)

        fail_safe_notifier.notify(config, from_color, to_color, error)

        expect(notifier).to have_received(:notify).with(config, from_color, to_color, error)
      end
    end

    context "when notification fails" do
      it "calls the error notifier with the exception" do
        allow(notifier).to receive(:notify).and_raise(error)
        allow(error_notifier).to receive(:call)

        fail_safe_notifier.notify(config, from_color, to_color, error)

        expect(error_notifier).to have_received(:call).with(error)
      end
    end
  end
end
