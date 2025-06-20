# frozen_string_literal: true

require "spec_helper"

RSpec.describe Stoplight::Config::UserDefaultConfig do
  subject(:user_config) { described_class.new }

  it "supports :error_rate symbol for traffic_control" do
    user_config.traffic_control = :error_rate
    expect(user_config.to_h[:traffic_control]).to be_a(Stoplight::TrafficControl::ErrorRate)
  end

  it "supports :consecutive_failures symbol for traffic_control" do
    user_config.traffic_control = :consecutive_failures
    expect(user_config.to_h[:traffic_control]).to be_a(Stoplight::TrafficControl::ConsecutiveFailures)
  end

  it "supports hash for error_rate with options" do
    user_config.traffic_control = {error_rate: {min_requests: 42}}
    tc = user_config.to_h[:traffic_control]
    expect(tc).to be_a(Stoplight::TrafficControl::ErrorRate)
    expect(tc.instance_variable_get(:@min_sample_size)).to eq(42)
  end

  it "supports hash for consecutive_failures with options" do
    user_config.traffic_control = {consecutive_failures: {}}
    tc = user_config.to_h[:traffic_control]
    expect(tc).to be_a(Stoplight::TrafficControl::ConsecutiveFailures)
  end

  it "raises for unknown hash key" do
    user_config.traffic_control = {unknown: {}}
    expect { user_config.to_h }.to raise_error(ArgumentError)
  end
end
