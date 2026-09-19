# frozen_string_literal: true

Then('{light} is in "{state}" state') do |light, state|
  expect(find_light(light).state).to eq(state)
end

Then(/^its color is (?:still )?(red|yellow|green)$/) do |color|
  pending
end

Then("{light} is unchanged") do |light|
  pending
end

Then("its stored metrics and state are gone") do
  pending
end

Then("the request succeeds") do
  pending
end

Then("the request fails with status {int}") do |status|
  pending
end

Then("I am redirected to the lights page") do
  expect(last_response).to be_redirect
  expect(URI(last_response.location).path).to eq(lights_path(Stoplight.__stoplight__default_system))
end

Then("I am redirected to the lights page for system {string}") do |system_name|
  pending
end

Then("I am redirected to the lights page for the default system") do
  pending
end

Then("the configuration fails with error:") do |table|
  pending
end

Then(/^read-only mode is (on|off)$/) do |mode|
  pending
end

Then("I am told to check that the admin uses the same data store as the application") do
  pending
end

Then("I am told the panel is running in read-only mode") do
  pending
end

Then("I am told to configure a different data store") do
  pending
end
