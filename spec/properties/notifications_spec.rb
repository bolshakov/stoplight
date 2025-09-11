# frozen_string_literal: true

require "rantly/rspec_extensions"

require "spec_helper"

RSpec.describe "Notifications" do
  shared_examples "notify about state changes" do
    let(:notifier) { notifier_class.new }

    let(:notifier_class) do
      Class.new(Stoplight::Notifier::Base) do
        def initialize
          @notifications = Hash.new { |hash, key| hash[key] = [] }
        end

        def notify(config, from_color, to_color, _error)
          @notifications[config.name] << [from_color, to_color]
        end

        def notifications(name)
          @notifications[name]
        end
      end
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
        light = Stoplight(
          SecureRandom.uuid,
          data_store:,
          cool_off_time: 3,
          notifiers: [notifier],
          recovery_threshold: 2
        )

        color_before_run = light.color
        notifications_before_run = notifier.notifications(light.name).count

        executions_sequence.each do |(should_fail, time_gap)|
          Timecop.travel(Time.now + time_gap)
          suppress(StandardError) { light.run { raise if should_fail } }

          color_after_run = light.color
          notifications = notifier.notifications(light.name)

          if color_before_run != color_after_run
            expect(notifications.count).to eq(notifications_before_run + 1),
              "Expected a notification when transitioning from #{color_before_run} to #{color_after_run}, but did not"

            expect(notifications.last).to eq([color_before_run, color_after_run]),
              "Expected notification to be from #{color_before_run} to #{color_after_run}, but was #{notifications.last}"
          end

          color_before_run = color_after_run
          notifications_before_run = notifications.count
        end
      end
    end
  end

  context "with memory data store" do
    let(:data_store) { Stoplight::DataStore::Memory.new }

    it_behaves_like "notify about state changes"
  end

  context "with redis data store", :redis do
    let(:data_store) { Stoplight::DataStore::Redis.new(redis) }

    it_behaves_like "notify about state changes"
  end
end
