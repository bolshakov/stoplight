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

  describe ".system_light" do
    subject(:light) { Stoplight.system_light(name) }

    it "prefix name with __stoplight__" do
      expect(light.name).to eq("__stoplight__#{name}")
    end
  end

  context "with settings" do
    subject(:light) { Stoplight(name, **settings) }

    let(:settings) { {**config_settings, **dependencies_settings} }
    let(:config_settings) do
      {
        cool_off_time: 1,
        threshold: 4,
        window_size: 5,
        tracked_errors: [StandardError],
        skipped_errors: [KeyError],
        recovery_threshold: 3
      }
    end
    let(:dependencies_settings) do
      {
        data_store: data_store,
        error_notifier: error_notifier,
        notifiers: notifiers
      }
    end
    let(:data_store) { Stoplight::DataStore::Memory.new }
    let(:error_notifier) { ->(error) { warn error } }
    let(:notifiers) { [Stoplight::Infrastructure::Notifier::IO.new($stdout)] }

    it "instantiates with the correct settings", pending: true do
      expect(light).to eq(Stoplight.__stoplight__default_light_factory.build_with(name:, **settings))
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
  end
end
