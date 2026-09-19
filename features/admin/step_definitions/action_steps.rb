# frozen_string_literal: true

When("I visit the admin root") do
  get "/"
end

When("I visit the lights page") do
  get lights_path(app.settings.systems.first)
end

When("I visit the lights page for system {string}") do |system_name|
  get lights_path(system_named(system_name))
end

When("I open the actions for {light}") do |light|
  pending
end

When("I lock {light} to {color}") do |light, color|
  patch light_path(light, "/lock"), color: color.to_s
end

When("I unlock {light}") do |light|
  pending
end

When("I remove {light}") do |light|
  pending
end

When("I lock all lights to {color}") do |color|
  pending
end

When("I lock all lights in system {string} to {color}") do |system_name, color|
  pending
end

When("{int} request(s) is/are made to {light}") do |count, light|
  pending
end

When("I request the lights JSON") do
  pending
end

When("I request the lights JSON twice") do
  pending
end

When("I request the lights JSON for system {string}") do |system_name|
  pending
end

When("I request the unscoped stats JSON") do
  pending
end

When(/^I send a (PATCH|DELETE) request to the (lock|unlock|lock-all|remove) endpoint$/) do |verb, endpoint|
  pending
end

When(/^I send a (GET|HEAD) request to the lights page$/) do |verb|
  pending
end

When("I configure a system with a non-persistent data store") do
  pending
end

When("the standalone panel boots") do
  pending
end
