# frozen_string_literal: true

Given(/^I subscribe to RunCompleted telemetry events$/) do
  Stoplight.telemetry.subscribe(Stoplight::Telemetry::RunCompleted) { |envelope| received_telemetry_events << envelope }
end

Then(/^I received (\d+) RunCompleted telemetry event(?:s)?$/) do |count|
  expect(received_telemetry_events.size).to eq(count.to_i)
end
