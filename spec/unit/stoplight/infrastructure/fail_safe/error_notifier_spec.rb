# frozen_string_literal: true

RSpec.describe Stoplight::Infrastructure::FailSafe::ErrorNotifier do
  subject(:fail_safe_error_notifier) { described_class.new(error_notifier: underlying_error_notifier) }

  let(:error) { StandardError.new("store failed") }

  context "when the underlying error notifier succeeds" do
    let(:underlying_error_notifier) { instance_double(Proc) }

    it "forwards the error" do
      allow(underlying_error_notifier).to receive(:call)

      fail_safe_error_notifier.call(error)

      expect(underlying_error_notifier).to have_received(:call).with(error)
    end
  end

  context "when the underlying error notifier raises" do
    let(:underlying_error_notifier) { ->(_) { raise StandardError.new("notifier boom") } }

    it "does not propagate the exception" do
      expect { fail_safe_error_notifier.call(error) }.not_to raise_error
    end

    it "warns when the underlying error notifier raises" do
      expect { fail_safe_error_notifier.call(error) }
        .to output(/Stoplight error_notifier raised: notifier boom/).to_stderr
    end
  end
end
