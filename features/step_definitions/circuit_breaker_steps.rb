# frozen_string_literal: true

Given(/^a light "([^"\s]+)" exists with:$/) do |name, table|
  self.current_light = configure_light(Stoplight(name), table)
end

Given(/^a light "([^"\s]+)" exists$/) do |name|
  self.current_light = Stoplight(name)
end

Given(/^(?:the light) enters (?:the )?red state$/) do
  until current_light.color == Stoplight::Color::RED
    capture_result do
      current_light.run { echo_service.call("hello") }
    end
  end
  expect(current_light.color).to eq(Stoplight::Color::RED)
end

Given(/^(?:the light) enters (?:the )?yellow state$/) do
  step("the light enters the red state")
  Timecop.travel(Time.now + 1) until current_light.color == Stoplight::Color::YELLOW

  expect(current_light.color).to eq(Stoplight::Color::YELLOW)
end

And(/^I make (\d+|a) request(?:s)? to the (?:protected )?service(?: with "([^"]+)" message)?$/) do |count, message|
  count = (count == "a") ? 1 : count.to_i
  count.times do |x|
    capture_result do
      current_light.run { echo_service.call(message || "hello #{x}") }
    end
  end
end

When(/^I lock the light to ([^"]*)$/) do |color|
  current_light.lock(color)
end

When(/^I unlock (?:the light|it$)/) do
  current_light.unlock
end

Given(/^(?:the light|it) is configured with:$/) do |table|
  self.current_light = configure_light(current_light, table)
end
