# frozen_string_literal: true

RSpec.describe Stoplight::Admin::Panel::Actions::LightDetail do
  subject(:call) { action.call(id) }

  let(:action) { described_class.new(config_registry:, storage:) }
  let(:config_registry) { instance_double(Stoplight::Admin::ConfigRegistry) }
  let(:storage) { instance_double(Stoplight::Wiring::System::Storage) }
  let(:id) { "light-id" }

  context "when no config is registered for the id" do
    before do
      allow(config_registry).to receive(:find_by_id).with(id).and_return(nil)
    end

    it "returns nil" do
      expect(call).to be_nil
    end
  end

  context "when a config is registered for the id" do
    let(:config) { instance_double(Stoplight::Domain::Config, id: "light-id", name: "checkout", recovery_threshold: 2) }
    let(:recovery_scheduled_after) { Time.now.utc + 30 }
    let(:metrics_last_error) { instance_double(Stoplight::Domain::Failure, error_class: "RuntimeError", error_message: "main store error") }
    let(:recovery_last_error) { instance_double(Stoplight::Domain::Failure, error_class: "RuntimeError", error_message: "recovery store error") }
    let(:metrics_snapshot) { instance_double(Stoplight::Domain::MetricsSnapshot, last_error: metrics_last_error) }
    let(:recovery_metrics_snapshot) do
      instance_double(Stoplight::Domain::MetricsSnapshot, last_error: recovery_last_error, consecutive_successes: 1)
    end

    before do
      allow(config_registry).to receive(:find_by_id).with(id).and_return(config)
      allow(storage).to receive(:state_snapshot).with(config).and_return(state_snapshot)
      allow(storage).to receive(:metrics_snapshot).with(config).and_return(metrics_snapshot)
      allow(storage).to receive(:recovery_metrics_snapshot).with(config).and_return(recovery_metrics_snapshot)
    end

    context "when the light is red" do
      let(:state_snapshot) do
        instance_double(Stoplight::Domain::StateSnapshot, color: Stoplight::Color::RED, locked_state: Stoplight::State::UNLOCKED,
          recovery_scheduled_after:)
      end

      it "reads the last error from the main metrics store" do
        expect(call).to have_attributes(last_error: metrics_last_error)
      end
    end

    context "when the light is yellow" do
      let(:state_snapshot) do
        instance_double(Stoplight::Domain::StateSnapshot, color: Stoplight::Color::YELLOW, locked_state: Stoplight::State::UNLOCKED,
          recovery_scheduled_after:)
      end

      it "reads the last error from the recovery metrics store, not the main store" do
        expect(call).to have_attributes(last_error: recovery_last_error)
      end
    end

    context "when the light is green" do
      let(:state_snapshot) do
        instance_double(Stoplight::Domain::StateSnapshot, color: Stoplight::Color::GREEN, locked_state: Stoplight::State::UNLOCKED,
          recovery_scheduled_after: nil)
      end

      it "builds a detail from the config and both snapshots" do
        expect(call).to have_attributes(
          id: "light-id",
          name: "checkout",
          color: Stoplight::Color::GREEN,
          lock_state: Stoplight::State::UNLOCKED,
          recovery_scheduled_after: nil,
          consecutive_successes: 1,
          recovery_threshold: 2
        )
      end
    end
  end
end
