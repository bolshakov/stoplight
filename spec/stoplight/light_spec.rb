# frozen_string_literal: true

RSpec.describe Stoplight::Light do
  let(:failure) do
    Stoplight::Failure.new(error.class.name, error.message, time)
  end
  let(:error) { error_class.new(error_message) }
  let(:error_class) { Class.new(StandardError) }
  let(:error_message) { random_string }
  let(:time) { Time.new }

  def random_string
    ("a".."z").to_a.sample(8).join
  end

  let(:config) { Stoplight.config_provider.provide(name, data_store:) }
  let(:light) { Stoplight::Light.new(config) }

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

  context "with memory data store" do
    let(:data_store) { Stoplight::DataStore::Memory.new }

    it_behaves_like "Stoplight::Light#state"
    it_behaves_like "Stoplight::Light#color"
    it_behaves_like "Stoplight::Light#run"
  end

  context "with redis data store", :redis do
    let(:data_store) { Stoplight::DataStore::Redis.new(redis) }

    it_behaves_like "Stoplight::Light#state"
    it_behaves_like "Stoplight::Light#color"
    it_behaves_like "Stoplight::Light#run"
  end
end
