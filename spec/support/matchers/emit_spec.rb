# frozen_string_literal: true

RSpec.describe "emit matcher" do
  let(:emitter) { TestTelemetryEmitter.new }
  let(:event_class) { Data.define(:outcome, :duration_ms) }
  let(:other_event_class) { Data.define(:reason) }

  it "matches when the block emits an instance of the given class" do
    expect { emitter.emit(event_class) { event_class.new(outcome: "success", duration_ms: 12) } }
      .to emit(event_class)
  end

  it "does not match when the block emits nothing" do
    expect {}.not_to emit(event_class)
  end

  it "does not match when the block emits a different event class" do
    expect { emitter.emit(other_event_class) { other_event_class.new(reason: "boom") } }
      .not_to emit(event_class)
  end

  it "ignores events emitted before the block runs" do
    emitter.emit(event_class) { event_class.new(outcome: "success", duration_ms: 12) }

    expect {}.not_to emit(event_class)
  end

  it "matches when the attributes given to `with` are equal" do
    expect { emitter.emit(event_class) { event_class.new(outcome: "success", duration_ms: 12) } }
      .to emit(event_class).with(outcome: "success")
  end

  it "does not match when the attributes given to `with` differ" do
    expect { emitter.emit(event_class) { event_class.new(outcome: "success", duration_ms: 12) } }
      .not_to emit(event_class).with(outcome: "failure")
  end

  it "supports composable matchers as `with` values" do
    expect { emitter.emit(event_class) { event_class.new(outcome: "success", duration_ms: 12) } }
      .to emit(event_class).with(duration_ms: be > 10)
  end

  it "explains what was emitted instead on failure" do
    expect {
      expect { emitter.emit(other_event_class) { other_event_class.new(reason: "boom") } }
        .to emit(event_class)
    }.to raise_error(RSpec::Expectations::ExpectationNotMetError, /#{Regexp.escape(event_class.to_s)}/)
  end
end
