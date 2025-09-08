# frozen_string_literal: true

match_color = "red|yellow|green"

Given(/^(?:the light|its) color is (?:the )?(#{match_color})$/) do |color|
  expect(current_light.color).to eq(color)
end

And(/^notification about transition from (#{match_color}) to (#{match_color}) is sent$/) do |from_color, to_color|
  notification = notifications.last_notification(current_light.name)
  expect(notification).not_to be_empty, "Expected a notification to be sent, but none was found."
  expect(notification)
    .to eq([from_color, to_color]),
      "Expected notification to be from #{from_color} to #{to_color}, but got #{notification.join(" -> ")}."
end

Then(/^(?:the light|it) returns "([^"]+)"$/) do |expected_result|
  if last_exception
    expect(last_exception).to be_nil, "Expected no exception, but got #{last_exception.class}: #{last_exception.message}"
  else
    expect(last_result).to eq(expected_result)
  end
end

Then(/^(?:the light|it) fails with error:$/) do |table|
  table.rows_hash.each_pair do |key, value|
    case key
    when "Type"
      exception_class = Object.const_get(value)
      expect(last_exception)
        .to be_kind_of(exception_class),
          "Expected exception to be of type #{value}, but got #{last_exception.inspect}"
    when "Message"
      expect(last_exception.message)
        .to eq(value),
          "Expected exception message to be '#{value}', but got '#{last_exception.message}'"
    else
      raise ArgumentError, "Unknown key: #{key}"
    end
  end
end
