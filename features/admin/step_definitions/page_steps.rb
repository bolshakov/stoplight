# frozen_string_literal: true

Then("I see {string}") do |text|
  expect(document.text).to include(text)
end

Then("I see {light}") do |light|
  expect(listed_light_names).to include(light.name)
end

Then("I do not see {light}") do |light|
  expect(listed_light_names).not_to include(light.name)
end

Then("I see no color counts") do
  expect(document.css('[data-role="color-count"]')).to be_empty
end

Then("the lights are listed in this order:") do |table|
  expect(listed_light_names).to eq(table.raw.map(&:first))
end

Then("the counts are:") do |table|
  pending
end

Then("the percentages are:") do |table|
  pending
end

Then("the {color} percentage is {int}") do |color, percentage|
  pending
end

Then("no system switcher is shown") do
  pending
end

Then("the system switcher offers systems {string} and {string}") do |first_system_name, second_system_name|
  pending
end

Then("the system switcher does not offer the default system") do
  pending
end

Then("the card for {light} is titled {string}") do |light, title|
  pending
end

Then("its message is {string}") do |message|
  pending
end

Then("its comment is {string}") do |comment|
  pending
end

Then("the card for {light} shows {string}") do |light, text|
  pending
end

Then("the card for {light} shows a threshold of {int}") do |light, threshold|
  pending
end

Then("it shows a window size of {int} seconds") do |seconds|
  pending
end

Then("the card for {light} shows a last check of {string}") do |light, last_check|
  pending
end

Then("the card for {light} shows no last check") do |light|
  pending
end

Then("the {string} control is disabled") do |control|
  pending
end

Then("it is marked as disabled to assistive technology") do
  pending
end

Then("it is titled {string}") do |title|
  pending
end

Then("the {string} control asks for confirmation") do |control|
  pending
end

Then("the {string} control does not ask for confirmation") do |control|
  pending
end
