# frozen_string_literal: true

class TestTelemetryEmitter
  include RSpec::Matchers

  def initialize
    @emitted = []
  end

  def emit(event_class)
    event = yield
    expect(event).to be_kind_of(event_class)
    @emitted << event
  end

  def emitted = @emitted.dup
end
