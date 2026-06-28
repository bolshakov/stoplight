# frozen_string_literal: true

RSpec.describe "Stoplight" do
  subject(:light) { Stoplight(name) }

  let(:name) { ("a".."z").to_a.shuffle.join }

  before do
    Stoplight.configure(trust_me_im_an_engineer: true) {}
  end

  it "is a class" do
    expect(light).to be_kind_of(Stoplight::Domain::Light)
  end

  describe "#name" do
    it "reads the name" do
      expect(light.name).to eql(name)
    end
  end

  context "with settings" do
    subject(:light) { Stoplight(name, **settings) }

    let(:settings) do
      {
        cool_off_time: 1,
        threshold: 4,
        window_size: 5,
        tracked_errors: [StandardError],
        skipped_errors: [KeyError],
        recovery_threshold: 3
      }
    end

    context "when unknown option is given" do
      let(:settings) do
        super().merge(unknown_option: "unknown")
      end

      it "raises an ArgumentError" do
        expect { light }.to raise_error(StandardError, /unknown_option/)
      end
    end
  end

  describe ".configure" do
    it "produces a warning if configured more than once" do
      Stoplight.configure {}

      expect do
        Stoplight.configure {}
      end.to output(/Stoplight reconfigured. Existing circuit breakers will not see new configuration/)
        .to_stderr
    end

    it "allows configuration with a block" do
      Stoplight.configure(trust_me_im_an_engineer: true) do |config|
        config.window_size = 30
      end

      light = Stoplight(SecureRandom.uuid, window_size: 30, threshold: 2, traffic_control: :consecutive_errors)

      light.run(->(_) {}) { raise }
      expect(light.color).to eq(Stoplight::Color::GREEN)

      Timecop.travel(Time.now + 31) do
        light.run(->(_) {}) { raise }
        expect(light.color).to eq(Stoplight::Color::GREEN)
      end
    end

    it "validates default configuration and does not apply invalid one" do
      expect do
        Stoplight.configure(trust_me_im_an_engineer: true) do |config|
          config.traffic_control = :unexpected
        end
      end.to raise_error(Stoplight::Error::ConfigurationError, /unsupported traffic_control strategy provided/)

      expect { Stoplight(SecureRandom.uuid) }.not_to raise_error
    end
  end

  describe ".__stoplight__system" do
    context "name is not in use yet" do
      subject(:system) { Stoplight.__stoplight__system(SecureRandom.uuid) }

      it { is_expected.to be_kind_of(Stoplight::Wiring::System) }
    end

    context "name is already in use" do
      subject(:system) { Stoplight.__stoplight__system(name) }

      let(:name) { SecureRandom.uuid }

      it "raises argument error" do
        Stoplight.__stoplight__system(name)

        expect { system }.to raise_error(ArgumentError)
      end
    end

    context "notifier circuit breaker isolation" do
      before do
        stub_const("BrokenNotifier", Class.new do
          def notify(info, from_color, to_color, error = nil)
            raise "notifier always fails"
          end
        end)

        stub_const("SpyNotifier", Class.new do
          attr_reader :notifications

          def initialize
            @notifications = []
          end

          def notify(info, from_color, to_color, error = nil)
            @notifications << [from_color, to_color]
          end
        end)
      end

      let(:spy_notifier) { SpyNotifier.new }

      it "a flaky notifier does not suppress notifications from an independent notifier" do
        # Three BrokenNotifiers of the same class are enough to exhaust the failover
        # system's default threshold of 3 in a single notifiers.each pass. If all
        # notifiers share one circuit breaker (the bug), the breaker trips before
        # SpyNotifier runs and SpyNotifier never sees the green→red transition.
        system = Stoplight.__stoplight__system(
          SecureRandom.uuid,
          threshold: 1,
          notifiers: [BrokenNotifier.new, BrokenNotifier.new, BrokenNotifier.new, spy_notifier]
        )

        system.light("payments").run(->(_) {}) { raise "dependency failure" }

        expect(spy_notifier.notifications).not_to be_empty
      end
    end
  end
end
