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

  describe "#with" do
    let(:fallback) { ->(_) {} }
    let(:failing_code) { -> { raise } }

    before do
      Stoplight.configure(trust_me_im_an_engineer: true) do |config|
        config.data_store = Stoplight::DataStore::Memory.new
      end
    end

    specify "with cool_off_time", :freeze do
      prototype_light = Stoplight("prototype", cool_off_time: 60, traffic_control: :consecutive_errors, threshold: 1)
      updated_light = prototype_light.with(name: "updated", cool_off_time: 30)

      updated_light.run(fallback, &failing_code)

      Timecop.travel(Time.now + 29) do
        expect(updated_light.color).to eq(Stoplight::Color::RED)
      end
      Timecop.travel(Time.now + 31) do
        expect(updated_light.color).to eq(Stoplight::Color::YELLOW)
      end

      prototype_light.run(fallback, &failing_code)

      Timecop.travel(Time.now + 59) do
        expect(prototype_light.color).to eq(Stoplight::Color::RED)
      end
      Timecop.travel(Time.now + 60) do
        expect(prototype_light.color).to eq(Stoplight::Color::YELLOW)
      end
    end

    specify "with data_store" do
      prototype_light_1 = Stoplight("prototype", threshold: 2, traffic_control: :consecutive_errors)
      prototype_light_2 = Stoplight("prototype", threshold: 2, traffic_control: :consecutive_errors)
      light_with_different_data_store = prototype_light_1.with(data_store: Stoplight::DataStore::Memory.new)

      prototype_light_1.run(fallback, &failing_code)
      prototype_light_2.run(fallback, &failing_code)
      expect(prototype_light_1.color).to eq(Stoplight::Color::RED)
      expect(prototype_light_2.color).to eq(Stoplight::Color::RED)

      expect(light_with_different_data_store.color).to eq(Stoplight::Color::GREEN)
    end

    describe "with error_notifier" do
      let(:error_notifier) { instance_double(Proc) }
      let(:prototype) { Stoplight("prototype", error_notifier:, threshold: 1, traffic_control: :consecutive_errors) }

      it "produces deprecation warning" do
        expect { prototype }.to output(
          include("Passing \"error_notifier\" to Stoplight('prototype') is deprecated and will be removed in v7.0.0.")
        ).to_stderr
      end

      context "when extended with data_store and error_notifier" do
        let(:updated_error_notifier) { instance_double(Proc) }

        let(:updated_data_store) { Stoplight::DataStore::Redis.new(Redis.new(url: SecureRandom.uuid)) }
        let(:updated_light) do
          prototype.with(name: "updated", error_notifier: updated_error_notifier, data_store: updated_data_store)
        end

        it "uses data store with new error notifier" do
          expect(updated_error_notifier).to receive(:call).with(be_kind_of(Redis::CannotConnectError))

          expect(updated_light.color).to eq(Stoplight::Color::GREEN)
        end
      end

      context "when extended with data_store" do
        let(:updated_data_store) { Stoplight::DataStore::Redis.new(Redis.new(url: SecureRandom.uuid)) } # not connectable
        let(:updated_light) { prototype.with(name: "updated", data_store: updated_data_store) }

        it "uses data store with inherited error notifier" do
          expect(error_notifier).to receive(:call).with(be_kind_of(Redis::CannotConnectError))

          expect(updated_light.color).to eq(Stoplight::Color::GREEN)
        end
      end

      context "when extended with notifiers and error_notifier" do
        let(:updated_error_notifier) { instance_double(Proc) }
        let(:updated_notifier) { Stoplight::Infrastructure::Notifier::Logger.new(StringIO.new) } # not a logger
        let(:updated_light) do
          prototype.with(name: "updated", error_notifier: updated_error_notifier, notifiers: [updated_notifier])
        end

        it "uses notifier with new error notifier" do
          expect(updated_error_notifier).to receive(:call).with(be_kind_of(NoMethodError))

          updated_light.run(fallback, &failing_code) # triggers green -> red notification
        end
      end

      context "when extended with data_store" do
        let(:updated_notifier) { Stoplight::Infrastructure::Notifier::Logger.new(StringIO.new) } # not a logger
        let(:updated_light) { prototype.with(name: "updated", notifiers: [updated_notifier]) }

        it "uses notifier with inherited notifier" do
          expect(error_notifier).to receive(:call).with(be_kind_of(NoMethodError))

          updated_light.run(fallback, &failing_code) # triggers green -> red notification
        end
      end
    end

    describe "with notifiers" do
      let(:prototype) do
        Stoplight("prototype", notifiers: [prototype_notifier], threshold: 1, traffic_control: :consecutive_errors)
      end

      let(:prototype_notifier) { Stoplight::Notifier::IO.new(prototype_string) }
      let(:prototype_string) { StringIO.new }

      context "when updated notifiers" do
        let(:updated) { prototype.with(name: "updated", notifiers: [updated_notifier]) }
        let(:updated_notifier) { Stoplight::Notifier::IO.new(updated_string) }
        let(:updated_string) { StringIO.new }

        it "notifies an updated notifier" do
          expect do
            updated.run(fallback, &failing_code)
          end.to change(updated_string, :string).to("Switching updated from green to red because RuntimeError \n")
        end

        it "does not notify a prototype notifier" do
          expect do
            updated.run(fallback, &failing_code)
          end.not_to change(prototype_string, :string)
        end
      end

      context "when not updated notifiers" do
        let(:updated) { prototype.with(name: "updated") }

        it "notifies a prototype notifier" do
          expect do
            updated.run(fallback, &failing_code)
          end.to change(prototype_string, :string).to("Switching updated from green to red because RuntimeError \n")
        end
      end
    end

    specify "with threshold" do
      prototype_light = Stoplight("prototype", threshold: 10, traffic_control: :consecutive_errors)
      updated_light = prototype_light.with(name: "updated", threshold: 1, traffic_control: :consecutive_errors)

      updated_light.run(fallback, &failing_code)
      expect(updated_light.color).to eq(Stoplight::Color::RED)

      9.times { prototype_light.run(fallback, &failing_code) }
      expect(prototype_light.color).to eq(Stoplight::Color::GREEN)

      prototype_light.run(fallback, &failing_code)
      expect(prototype_light.color).to eq(Stoplight::Color::RED)
    end

    specify "with window_size", :freeze do
      prototype_light = Stoplight("prototype", window_size: 60, threshold: 2, traffic_control: :consecutive_errors)
      updated_light = prototype_light.with(name: "updated", window_size: 30)

      updated_light.run(fallback, &failing_code)
      prototype_light.run(fallback, &failing_code)

      expect(updated_light.color).to eq(Stoplight::Color::GREEN)
      expect(prototype_light.color).to eq(Stoplight::Color::GREEN)

      Timecop.travel(Time.now + 31) do
        updated_light.run(fallback, &failing_code)
        prototype_light.run(fallback, &failing_code)

        expect(updated_light.color).to eq(Stoplight::Color::GREEN)
        expect(prototype_light.color).to eq(Stoplight::Color::RED)
      end
    end

    specify "with tracked_errors" do
      prototype_light = Stoplight("prototype", tracked_errors: [KeyError])
      updated_light = prototype_light.with(name: "updated", tracked_errors: [Timeout::Error])

      expect do
        updated_light.run(fallback) { raise Timeout::Error }
      end.not_to raise_error

      expect do
        prototype_light.run(fallback) { raise Timeout::Error }
      end.to raise_error(Timeout::Error)

      expect do
        updated_light.run(fallback) { raise KeyError }
      end.to raise_error(KeyError)

      expect do
        prototype_light.run(fallback) { raise KeyError }
      end.not_to raise_error
    end

    specify "with skipped_errors" do
      prototype_light = Stoplight("prototype", skipped_errors: [KeyError])
      updated_light = prototype_light.with(name: "updated", skipped_errors: [Timeout::Error])

      expect do
        updated_light.run(fallback) { raise Timeout::Error }
      end.to raise_error

      expect do
        prototype_light.run(fallback) { raise Timeout::Error }
      end.not_to raise_error(Timeout::Error)

      expect do
        updated_light.run(fallback) { raise KeyError }
      end.not_to raise_error

      expect do
        prototype_light.run(fallback) { raise KeyError }
      end.to raise_error(KeyError)
    end

    specify "with traffic control" do
      prototype_light = Stoplight("prototype", traffic_control: :consecutive_errors, threshold: 1, window_size: 60)
      updated_light = prototype_light.with(name: "updated", traffic_control: :error_rate, threshold: 0.5)

      prototype_light.run(fallback, &failing_code)
      expect(prototype_light.color).to eq(Stoplight::Color::RED)

      updated_light.run(fallback, &failing_code)
      expect(updated_light.color).to eq(Stoplight::Color::GREEN)
    end
  end

  describe "#==" do
    let(:light) { Stoplight("foo") }
    let(:light_with_the_same_name) { Stoplight("foo") }
    let(:light_with_different_name) { Stoplight("bar") }
    let(:light_with_different_config) { Stoplight("foo", cool_off_time: 10) }

    it "returns true when the lights have the same configuration" do
      expect(light).to eq(light_with_the_same_name)
      expect(light).not_to eq(light_with_different_name)
      expect(light).not_to eq(light_with_different_config)
      expect(light.with(cool_off_time: 10)).to eq(light_with_different_config)
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
