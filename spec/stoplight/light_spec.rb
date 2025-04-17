# frozen_string_literal: true

require "spec_helper"

RSpec.describe Stoplight::Light do
  let(:name) { ("a".."z").to_a.shuffle.join }

  describe "#==" do
    let(:light) { Stoplight("foo") }
    let(:light_with_the_same_name) { Stoplight("foo") }
    let(:light_with_different_name) { Stoplight("bar") }
    let(:light_with_different_config) { Stoplight("foo").with_cool_off_time(10) }

    it "returns true when the lights have the same configuration" do
      expect(light == light_with_the_same_name).to eq(true)
      expect(light == light_with_different_name).to eq(false)
      expect(light == light_with_different_config).to eq(false)
      expect(light.with_cool_off_time(10) == light_with_different_config).to eq(true)
    end
  end
end
