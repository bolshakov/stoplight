# frozen_string_literal: true

require "rantly/rspec_extensions"

require "spec_helper"

RSpec.describe "Stoplight::Light#color" do
  context "with memory data store" do
    specify "transition to color" do
      property_of {
        array(10) { choose(Stoplight::Color::GREEN, Stoplight::Color::RED, Stoplight::Color::YELLOW) }
      }.check do |color_sequence|
        data_store = Stoplight::DataStore::Memory.new
        light = Stoplight(SecureRandom.uuid, data_store:)
        config = light.config

        color_sequence.each do |color|
          data_store.transition_to_color(config, color)
        end

        expect(light.color).to eq(color_sequence.last)
      end
    end
  end

  context "with redis data store", :redis do
    specify "transition to color" do
      property_of {
        array(10) { choose(Stoplight::Color::GREEN, Stoplight::Color::RED, Stoplight::Color::YELLOW) }
      }.check do |color_sequence|
        data_store = Stoplight::DataStore::Redis.new(redis)
        light = Stoplight(SecureRandom.uuid, data_store:)
        config = light.config

        color_sequence.each do |color|
          data_store.transition_to_color(config, color)
        end

        expect(light.color).to eq(color_sequence.last)
      end
    end
  end
end
