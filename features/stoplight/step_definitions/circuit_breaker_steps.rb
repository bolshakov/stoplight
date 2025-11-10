# frozen_string_literal: true

Given(/^(?:I update )?global configuration:$/) do |table|
  Stoplight.configure(trust_me_im_an_engineer: true) do |config|
    collect_settings(table).each_pair do |setting, value|
      config.public_send("#{setting}=", value)
    end
  end
end

Given(/^a light (?:"([^"\s]+)" )?configured with:$/) do |name, table|
  self.current_light = configure_light(name || SecureRandom.hex, table)
end

Given(/^a light (?:"([^"\s]+)" )?exists$/) do |name|
  self.current_light = configure_light(name || SecureRandom.hex)
end

Given(/^(?:the light) enters red state$/) do
  until current_light.color == Stoplight::Color::RED
    capture_result do
      current_light.run { echo_service.call("hello") }
    end
  end
  expect(current_light.color).to eq(Stoplight::Color::RED)
end

Given(/^(?:the light) enters yellow state$/) do
  step("the light enters red state")
  Timecop.travel(Time.now + 1) until current_light.color == Stoplight::Color::YELLOW

  expect(current_light.color).to eq(Stoplight::Color::YELLOW)
end

Given(/^(?:the light) enters green state$/) do
  until current_light.color == Stoplight::Color::GREEN
    capture_result do
      current_light.run { echo_service.call("hello") }
    end
  end
  expect(current_light.color).to eq(Stoplight::Color::GREEN)
end

And(/^(\d+) request(?:s)? (?:is|are) made(?: with "([^"]+)" message)?(?: (?:with|and) fallback "([^"]+)")?$/) do |count, message, fallback|
  if fallback
    fallback_proc = ->(error) do
      self.last_fallback_received_argument = error
      fallback
    end
  end

  count.to_i.times do |x|
    capture_result do
      current_light.run(fallback_proc) do
        echo_service.call(message || "hello #{x}")
      end
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
