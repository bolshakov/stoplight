# frozen_string_literal: true

RSpec.describe Stoplight::Domain::LockControl do
  subject(:lock_control) { described_class.new(state_store:, emitter:) }

  let(:state_store) { instance_double(NullStateStore) }
  let(:emitter) { TestTelemetryEmitter.new }
  let(:state_snapshot) do
    Stoplight::Domain::StateSnapshot.new(
      breached_at: nil,
      locked_state: Stoplight::State::UNLOCKED,
      recovery_scheduled_after: nil,
      recovery_started_at: nil,
      time: Time.now
    )
  end

  before do
    allow(state_store).to receive(:state_snapshot).and_return(state_snapshot)
  end

  describe "#lock" do
    context "with green color" do
      it "locks green color" do
        expect(state_store).to receive(:set_state).with(Stoplight::State::LOCKED_GREEN)

        lock_control.lock(Stoplight::Color::GREEN)
      end
    end

    context "with red color" do
      it "locks red color" do
        expect(state_store).to receive(:set_state).with(Stoplight::State::LOCKED_RED)

        lock_control.lock(Stoplight::Color::RED)
      end
    end

    context "with incorrect color" do
      let(:color) { "incorrect-color" }

      it "raises Error::IncorrectColor and does not write state" do
        expect(state_store).to_not receive(:set_state)

        expect { lock_control.lock(color) }.to raise_error(Stoplight::Error::IncorrectColor)
      end
    end

    it "emits a LockChanged event describing the transition" do
      allow(state_store).to receive(:set_state)

      expect { lock_control.lock(Stoplight::Color::GREEN) }.to emit(Stoplight::Domain::Telemetry::LockChanged).with(
        from_color: Stoplight::Color::GREEN,
        to_color: Stoplight::Color::GREEN,
        from_state: Stoplight::State::UNLOCKED,
        to_state: Stoplight::State::LOCKED_GREEN
      )
    end

    it "reports the from_color/from_state read before the write, not the state left behind by it" do
      written = false
      post_write_snapshot = Stoplight::Domain::StateSnapshot.new(
        breached_at: nil,
        locked_state: Stoplight::State::LOCKED_RED,
        recovery_scheduled_after: nil,
        recovery_started_at: nil,
        time: Time.now
      )
      allow(state_store).to receive(:set_state) { written = true }
      allow(state_store).to receive(:state_snapshot) { written ? post_write_snapshot : state_snapshot }

      expect { lock_control.lock(Stoplight::Color::GREEN) }.to emit(Stoplight::Domain::Telemetry::LockChanged).with(
        from_color: Stoplight::Color::GREEN,
        to_color: Stoplight::Color::GREEN,
        from_state: Stoplight::State::UNLOCKED,
        to_state: Stoplight::State::LOCKED_GREEN
      )
    end

    context "when locking an unlocked, already-red light to red" do
      let(:state_snapshot) do
        Stoplight::Domain::StateSnapshot.new(
          breached_at: Time.now,
          locked_state: Stoplight::State::UNLOCKED,
          recovery_scheduled_after: nil,
          recovery_started_at: nil,
          time: Time.now
        )
      end

      it "reports the from_color/from_state read from the snapshot before the write" do
        allow(state_store).to receive(:set_state)

        expect { lock_control.lock(Stoplight::Color::RED) }.to emit(Stoplight::Domain::Telemetry::LockChanged).with(
          from_color: Stoplight::Color::RED,
          to_color: Stoplight::Color::RED,
          from_state: Stoplight::State::UNLOCKED,
          to_state: Stoplight::State::LOCKED_RED
        )
      end
    end

    context "when locking an unlocked, green light to red" do
      it "reports from_color distinctly from to_color" do
        allow(state_store).to receive(:set_state)

        expect { lock_control.lock(Stoplight::Color::RED) }.to emit(Stoplight::Domain::Telemetry::LockChanged).with(
          from_color: Stoplight::Color::GREEN,
          to_color: Stoplight::Color::RED,
          from_state: Stoplight::State::UNLOCKED,
          to_state: Stoplight::State::LOCKED_RED
        )
      end
    end

    context "when locking an already-locked-green light to green again" do
      let(:state_snapshot) do
        Stoplight::Domain::StateSnapshot.new(
          breached_at: nil,
          locked_state: Stoplight::State::LOCKED_GREEN,
          recovery_scheduled_after: nil,
          recovery_started_at: nil,
          time: Time.now
        )
      end

      it "still emits a LockChanged event, even though the lock state does not change" do
        allow(state_store).to receive(:set_state)

        expect { lock_control.lock(Stoplight::Color::GREEN) }.to emit(Stoplight::Domain::Telemetry::LockChanged).with(
          from_color: Stoplight::Color::GREEN,
          to_color: Stoplight::Color::GREEN,
          from_state: Stoplight::State::LOCKED_GREEN,
          to_state: Stoplight::State::LOCKED_GREEN
        )
      end
    end

    context "when nobody is subscribed to LockChanged" do
      let(:emitter) { instance_double(Stoplight::Domain::Telemetry::Emitter, subscribed?: false, emit: nil) }

      it "does not pay for a state snapshot read nobody will see" do
        expect(state_store).to_not receive(:state_snapshot)
        allow(state_store).to receive(:set_state)

        lock_control.lock(Stoplight::Color::GREEN)
      end
    end
  end

  describe "#unlock" do
    it "sets state to unlocked" do
      expect(state_store).to receive(:set_state).with(Stoplight::State::UNLOCKED)

      lock_control.unlock
    end

    it "emits a LockChanged event describing the transition" do
      allow(state_store).to receive(:set_state)

      expect { lock_control.unlock }.to emit(Stoplight::Domain::Telemetry::LockChanged).with(
        from_color: Stoplight::Color::GREEN,
        to_color: Stoplight::Color::GREEN,
        from_state: Stoplight::State::UNLOCKED,
        to_state: Stoplight::State::UNLOCKED
      )
    end

    it "reports the from_color/from_state read before the write, not the state left behind by it" do
      written = false
      pre_write_snapshot = Stoplight::Domain::StateSnapshot.new(
        breached_at: nil,
        locked_state: Stoplight::State::LOCKED_RED,
        recovery_scheduled_after: nil,
        recovery_started_at: nil,
        time: Time.now
      )
      post_write_snapshot = Stoplight::Domain::StateSnapshot.new(
        breached_at: nil,
        locked_state: Stoplight::State::UNLOCKED,
        recovery_scheduled_after: nil,
        recovery_started_at: nil,
        time: Time.now
      )
      allow(state_store).to receive(:set_state) { written = true }
      allow(state_store).to receive(:state_snapshot) { written ? post_write_snapshot : pre_write_snapshot }

      expect { lock_control.unlock }.to emit(Stoplight::Domain::Telemetry::LockChanged).with(
        from_color: Stoplight::Color::RED,
        to_color: Stoplight::Color::GREEN,
        from_state: Stoplight::State::LOCKED_RED,
        to_state: Stoplight::State::UNLOCKED
      )
    end

    context "when unlocking a red-locked light with no breach underneath" do
      let(:state_snapshot) do
        Stoplight::Domain::StateSnapshot.new(
          breached_at: nil,
          locked_state: Stoplight::State::LOCKED_RED,
          recovery_scheduled_after: nil,
          recovery_started_at: nil,
          time: Time.now
        )
      end

      it "derives to_color from the state that results after unlocking, not the pre-unlock color" do
        allow(state_store).to receive(:set_state)

        expect { lock_control.unlock }.to emit(Stoplight::Domain::Telemetry::LockChanged).with(
          from_color: Stoplight::Color::RED,
          to_color: Stoplight::Color::GREEN,
          from_state: Stoplight::State::LOCKED_RED,
          to_state: Stoplight::State::UNLOCKED
        )
      end
    end

    context "when unlocking a red-locked light with a recovery already started underneath" do
      let(:state_snapshot) do
        Stoplight::Domain::StateSnapshot.new(
          breached_at: Time.now,
          locked_state: Stoplight::State::LOCKED_RED,
          recovery_scheduled_after: nil,
          recovery_started_at: Time.now,
          time: Time.now
        )
      end

      it "derives to_color as yellow, not red or green" do
        allow(state_store).to receive(:set_state)

        expect { lock_control.unlock }.to emit(Stoplight::Domain::Telemetry::LockChanged).with(
          from_color: Stoplight::Color::RED,
          to_color: Stoplight::Color::YELLOW,
          from_state: Stoplight::State::LOCKED_RED,
          to_state: Stoplight::State::UNLOCKED
        )
      end
    end
  end
end
