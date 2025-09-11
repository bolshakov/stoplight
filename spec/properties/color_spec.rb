# frozen_string_literal: true

require "rantly/rspec_extensions"

require "spec_helper"

RSpec.describe "Stoplight::Light#color" do
  shared_examples "transition to color" do
    specify "transition to color" do
      property_of {
        array(10) { choose(Stoplight::Color::GREEN, Stoplight::Color::RED, Stoplight::Color::YELLOW) }
      }.check do |color_sequence|
        light = Stoplight(SecureRandom.uuid, data_store:)
        config = light.config

        color_sequence.each do |color|
          data_store.transition_to_color(config, color)
        end

        expect(light.color).to eq(color_sequence.last)
      end
    end
  end

  shared_examples "state machine" do
    let(:state_machine) do
      {
        Stoplight::Color::GREEN => [
          Stoplight::Color::GREEN,
          Stoplight::Color::RED
        ],
        Stoplight::Color::RED => [
          Stoplight::Color::RED,
          Stoplight::Color::YELLOW
        ],
        Stoplight::Color::YELLOW => [
          Stoplight::Color::YELLOW,
          Stoplight::Color::GREEN,
          Stoplight::Color::RED
        ]
      }
    end

    around do |example|
      safe_mode = Timecop.safe_mode?
      Timecop.safe_mode = false

      example.run

      Timecop.safe_mode = safe_mode
      Timecop.return
    end

    specify "performs allowed transitions" do
      property_of {
        array(20) { [choose(true, false), range(1, 10)] }
      }.check do |executions_sequence|
        light = Stoplight(SecureRandom.uuid, data_store:, cool_off_time: 5, recovery_threshold: 2)
        transitions = []

        executions_sequence.each do |(should_fail, time_gap)|
          Timecop.travel(Time.now + time_gap)

          suppress(StandardError) do
            light.run { raise if should_fail }
          end
          transitions << light.color
        end

        transitions.each_cons(2) do |from, to|
          expect(state_machine[from]).to include(to), "Invalid transition from #{from} to #{to}"
        end
      end
    end
  end

  context "with memory data store" do
    let(:data_store) { Stoplight::DataStore::Memory.new }

    it_behaves_like "transition to color"
    it_behaves_like "state machine"
  end

  context "with redis data store", :redis do
    let(:data_store) { Stoplight::DataStore::Redis.new(redis) }

    it_behaves_like "transition to color"
    it_behaves_like "state machine"
  end
end
