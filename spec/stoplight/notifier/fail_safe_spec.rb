# frozen_string_literal: true

require "spec_helper"

RSpec.describe Stoplight::Notifier::FailSafe do
  describe "#notify" do
    subject(:fail_safe_notifier) { described_class.new(notifier) }

    let(:notifier) { instance_double(Stoplight::Notifier::Base) }
    let(:config) { instance_double(Stoplight::Light::Config, error_notifier: error_notifier) }
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

  describe ".wrap" do
    subject(:fail_safe) { described_class.wrap(notifier) }

    context "when notifier is FailSafe already" do
      let(:notifier) { Stoplight::Notifier::FailSafe.new(instance_double(Stoplight::Notifier::Base)) }

      it "returns itself" do
        expect(fail_safe).to be(notifier)
      end
    end

    context "when notifier is not FailSafe" do
      let(:notifier) { instance_double(Stoplight::Notifier::Base) }

      it "returns a new FailSafe instance" do
        expect(fail_safe).to be_a(Stoplight::Notifier::FailSafe)
      end
    end
  end
end
