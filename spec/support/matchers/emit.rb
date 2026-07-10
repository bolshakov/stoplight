# frozen_string_literal: true

# Asserts that a block emits an event through the example's `emitter`
# (a TestTelemetryEmitter). Usage:
#
#   expect { light.run { "ok" } }.to emit(Stoplight::Domain::Telemetry::RunCompleted)
#     .with(outcome: "success")
RSpec::Matchers.define :emit do |event_class|
  supports_block_expectations

  match do |block|
    events_before = emitter.emitted.size
    block.call
    @new_events = emitter.emitted.drop(events_before)
    @matching_event = @new_events.find { |event| event.instance_of?(event_class) && attributes_match?(event) }

    !@matching_event.nil?
  end

  chain :with do |attributes|
    @attributes = attributes
  end

  define_method(:attributes_match?) do |event|
    @actual = (@attributes || {}).keys.to_h do |name|
      [name, event.public_send(name)]
    end

    @attributes.nil? || values_match?(@attributes, @actual)
  end

  description do
    @attributes ? "emit #{event_class} with #{@attributes.inspect}" : "emit #{event_class}"
  end

  failure_message do
    "expected to #{description}, but emitted: #{@new_events.inspect}"
  end

  failure_message_when_negated do
    "expected not to #{description}, but emitted: #{@matching_event.inspect}"
  end

  diffable
end
