# frozen_string_literal: true

require "timecop"

When(/^(\d+) (seconds|minutes|hours|days) elapsed$/) do |seconds, unit|
  case unit
  when "seconds"
    seconds = seconds.to_i
  when "minutes"
    seconds = seconds.to_i * 60
  when "hours"
    seconds = seconds.to_i * 60 * 60
  when "days"
    seconds = seconds.to_i * 60 * 60 * 24
  else
    raise ArgumentError, "Unknown time unit: #{unit}"
  end
  Timecop.travel(Time.now + seconds)
end

When(/^the protected service starts failing with "([^"]+)"(?: again)?$/) do |error_message|
  echo_service.fail_with(StandardError.new(error_message))
end

When(/^the protected service starts failing with:$/) do |table|
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

And(/^the protected service (?:recovers and starts|is) functioning normally$/) do
  echo_service.recover
end
