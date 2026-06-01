# frozen_string_literal: true

RSpec.describe "Light" do
  describe "Stoplight" do
    let(:fallback) { ->(_) {} }
    let(:failing_code) { -> { raise } }

    before do
      Stoplight.configure(trust_me_im_an_engineer: true) do |config|
        config.data_store = Stoplight::DataStore::Memory.new
      end
    end

    specify "with cool_off_time", :freeze do
      light = Stoplight(SecureRandom.uuid, cool_off_time: 30, traffic_control: :consecutive_errors, threshold: 1)

      light.run(fallback, &failing_code)

      Timecop.travel(Time.now + 29) do
        expect(light.color).to eq(Stoplight::Color::RED)
      end
      Timecop.travel(Time.now + 31) do
        expect(light.color).to eq(Stoplight::Color::YELLOW)
      end
    end

    specify "with threshold" do
      light = Stoplight(SecureRandom.uuid, threshold: 1, traffic_control: :consecutive_errors)

      light.run(fallback, &failing_code)
      expect(light.color).to eq(Stoplight::Color::RED)
    end

    specify "with window_size", :freeze do
      light = Stoplight(SecureRandom.uuid, window_size: 30, threshold: 2, traffic_control: :consecutive_errors)

      light.run(fallback, &failing_code)
      expect(light.color).to eq(Stoplight::Color::GREEN)

      Timecop.travel(Time.now + 31) do
        light.run(fallback, &failing_code)
        expect(light.color).to eq(Stoplight::Color::GREEN)
      end
    end

    specify "with tracked_errors" do
      light = Stoplight(SecureRandom.uuid, tracked_errors: Timeout::Error)

      expect do
        light.run(fallback) { raise Timeout::Error }
      end.not_to raise_error

      expect do
        light.run(fallback) { raise KeyError }
      end.to raise_error(KeyError)
    end

    specify "with skipped_errors" do
      light = Stoplight(SecureRandom.uuid, skipped_errors: Timeout::Error)

      expect do
        light.run(fallback) { raise Timeout::Error }
      end.to raise_error

      expect do
        light.run(fallback) { raise KeyError }
      end.not_to raise_error
    end

    context "with traffic control" do
      specify "with error rate" do
        light = Stoplight(SecureRandom.uuid, traffic_control: :error_rate, threshold: 0.5, window_size: 60)

        5.times { light.run(fallback) {} }
        expect(light.color).to eq(Stoplight::Color::GREEN)

        5.times { light.run(fallback, &failing_code) }
        expect(light.color).to eq(Stoplight::Color::RED)
      end

      specify "with consecutive errors" do
        light = Stoplight(SecureRandom.uuid, traffic_control: :consecutive_errors, threshold: 3)

        2.times { light.run(fallback, &failing_code) }
        expect(light.color).to eq(Stoplight::Color::GREEN)

        light.run(fallback, &failing_code)
        expect(light.color).to eq(Stoplight::Color::RED)
      end

      specify "when unexpected strategy provided" do
        expect do
          Stoplight(SecureRandom.uuid, traffic_control: :unknown)
        end.to raise_error(Stoplight::Error::ConfigurationError, <<~ERROR)
          unsupported traffic_control strategy provided (`unknown`). Supported options:
            * :consecutive_errors
            * :error_rate
        ERROR
      end
    end

    context "with traffic recovery" do
      specify "when :consecutive_successes" do
        cool_off_time = 20
        light = Stoplight(SecureRandom.uuid, traffic_recovery: :consecutive_successes, recovery_threshold: 2, cool_off_time:)

        until light.color == Stoplight::Color::RED
          light.run(fallback, &failing_code)
        end

        Timecop.travel(Time.now + cool_off_time) do
          light.run {}
          expect(light.color).to eq(Stoplight::Color::YELLOW)

          light.run {}
          expect(light.color).to eq(Stoplight::Color::GREEN)
        end
      end

      specify "when unexpected strategy provided" do
        expect do
          Stoplight(SecureRandom.uuid, traffic_recovery: :unknown)
        end.to raise_error(Stoplight::Error::ConfigurationError, <<~ERROR)
          unsupported traffic_recovery strategy provided (`unknown`). Supported options:
            * :consecutive_successes
        ERROR
      end
    end
  end

  describe "#==" do
    let(:light) { Stoplight("foo") }
    let(:light_with_different_name) { Stoplight("bar") }
    let(:light_with_different_cool_off_time) { Stoplight("foo", cool_off_time: 10) }

    it "returns true when the lights have the same configuration" do
      expect(light).to eq(light)
      expect(light).not_to eq(light_with_different_name)
      expect(light).not_to eq(light_with_different_cool_off_time)
    end
  end

  describe "#lock" do
    let(:light) { Stoplight(SecureRandom.uuid) }

    specify "initially unlocked" do
      expect(light.state).to eq(Stoplight::State::UNLOCKED)
    end

    specify "locking green" do
      expect do
        light.lock(Stoplight::Color::GREEN)
      end.to change(light, :state).to eq(Stoplight::State::LOCKED_GREEN)
    end

    specify "locking red" do
      expect do
        light.lock(Stoplight::Color::RED)
      end.to change(light, :state).to eq(Stoplight::State::LOCKED_RED)
    end

    specify "locking yellow" do
      expect do
        light.lock(Stoplight::Color::YELLOW)
      end.to raise_error(Stoplight::Error::IncorrectColor)
    end
  end

  describe "#unlock" do
    let(:light) { Stoplight(SecureRandom.uuid) }

    specify "unlocked light" do
      expect do
        light.unlock
      end.not_to change(light, :state).from(Stoplight::State::UNLOCKED)
    end

    specify "locked light" do
      light.lock(Stoplight::Color::GREEN)

      expect do
        light.unlock
      end.to change(light, :state).to(Stoplight::State::UNLOCKED)
    end
  end
end
