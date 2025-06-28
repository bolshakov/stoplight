# frozen_string_literal: true

RSpec.describe "Stoplight" do
  subject(:light) { Stoplight(name) }

  let(:name) { ("a".."z").to_a.shuffle.join }

  it "creates a stoplight" do
    config = Stoplight.default_config.with(name:)
    expect(light).to eq(Stoplight::Light.new(config))
  end

  it "is a class" do
    expect(light).to be_kind_of(Stoplight::Light)
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
      config = Stoplight.default_config.with(name:, **settings)
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
    it "produces a warning if configured more than once" do
      Stoplight.configure {}

      expect do
        Stoplight.configure {}
      end.to output(/Stoplight reconfigured. Existing circuit breakers will not see new configuration. New configuration/)
        .to_stderr
    end

    it "allows configuration with a block" do
      Stoplight.configure(trust_me_im_an_engineer: true) do |config|
        config.window_size = 94
      end
      expect(Stoplight.default_config.with(name: "")).to have_attributes(
        window_size: 94
      )
    end
  end
end
