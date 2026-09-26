# frozen_string_literal: true

When(/^(\d+) seconds? have elapsed$/) do |seconds|
  sleep(seconds.to_i)
end

When(/^the service starts failing with "([^"]+)"(?: again)?$/) do |error_message|
  echo_service.fail_with(StandardError.new(error_message))
end

When(/^the service starts failing with:$/) do |table|
  error_class = StandardError
  error_message = nil
  table.rows_hash.each_pair do |option, value|
    case option
    when "Type"
      error_class = Object.const_get(value)
    when "Message"
      error_message = value
    else
      raise ArgumentError, "Unknown option: #{option}"
    end
  end

  if error_message
    echo_service.fail_with(error_class.new(error_message))
  else
    echo_service.fail_with(error_class.new)
  end
end

And(/^the service (?:recovers and starts|is) functioning normally$/) do
  echo_service.recover
end
