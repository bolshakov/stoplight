# frozen_string_literal: true

require "spec_helper"

RSpec.describe Stoplight do
  it "is a module" do
    expect(described_class).to be_a(Module)
  end

  describe ".default_notifiers" do
    it "is initially the default" do
      expect(described_class.default_notifiers)
        .to eql(Stoplight::Default::NOTIFIERS)
    end
  end

  describe ".default_data_store" do
    it "is initially the default" do
      expect(described_class.default_data_store)
        .to eql(Stoplight::Default::DATA_STORE)
    end
  end

  describe ".default_error_notifier" do
    it "is initially the default" do
      expect(described_class.default_error_notifier)
        .to eql(Stoplight::Default::ERROR_NOTIFIER)
    end
  end
end

RSpec.describe "Stoplight" do
  subject(:light) { Stoplight(name) }

  let(:name) { ("a".."z").to_a.shuffle.join }

  it "creates a stoplight" do
    config = Stoplight::Light::Config.new(name: name)
    expect(light).to eq(Stoplight::Light.new(config))
  end

  it "is a class" do
    expect(light).to be_kind_of(Stoplight::CircuitBreaker)
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
        data_store: data_store,
        error_notifier: error_notifier,
        notifiers: notifiers,
        threshold: 4,
        window_size: 5,
        tracked_errors: [StandardError],
        skipped_errors: [KeyError]
      }
    end
    let(:data_store) { Stoplight::DataStore::Memory.new }
    let(:error_notifier) { ->(error) { warn error } }
    let(:notifiers) { [Stoplight::Notifier::IO.new($stdout)] }

    it "instantiates with the correct settings" do
      config = Stoplight::Light::Config.new(name: name, **settings)
      expect(light).to eq(Stoplight::Light.new(config))
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
    before { Stoplight.reset_config! }
    after { Stoplight.reset_config! }

    it "raises an error if configured more than once" do
      Stoplight.configure {}
      expect { Stoplight.configure {} }.to raise_error(Stoplight::Error::ConfigurationError, "Stoplight must be configured only once")
    end

    it "allows configuration with a block" do
      Stoplight.configure do |config|
        config.window_size = 94
      end
      expect(Stoplight.config_provider.provide("")).to have_attributes(
        window_size: 94
      )
    end
  end
end
