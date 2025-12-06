# frozen_string_literal: true

RSpec.describe Stoplight::Wiring::NotifierFactory do
  subject(:fail_safe) { described_class.create(notifier:, error_notifier:) }
  let(:error_notifier) { instance_double(Proc) }

  context "when notifier is FailSafe already" do
    let(:notifier) do
      Stoplight::Infrastructure::Notifier::FailSafe.new(
        notifier: instance_double(Stoplight::Domain::StateTransitionNotifier),
        error_notifier: error_notifier
      )
    end

    it "returns itself" do
      expect(fail_safe).to be(notifier)
    end
  end

  context "when notifier is not FailSafe" do
    let(:notifier) { instance_double(Stoplight::Domain::StateTransitionNotifier) }

    it "returns a new FailSafe instance" do
      expect(fail_safe).to be_a(Stoplight::Infrastructure::Notifier::FailSafe)
    end
  end
end
