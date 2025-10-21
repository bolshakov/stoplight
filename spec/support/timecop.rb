# frozen_string_literal: true

require "timecop"

RSpec.configure do |config|
  config.around(:each, freeze: ->(value) { value.present? }) do |example|
    time = Time.now.to_i
    Timecop.freeze(time) { example.run }
  end
end
