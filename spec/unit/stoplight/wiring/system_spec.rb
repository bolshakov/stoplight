# frozen_string_literal: true

RSpec.describe Stoplight::Wiring::System do
  subject!(:system) { described_class.new(config: system_config) }

  describe "#light" do
    let(:system_config) { Stoplight::Wiring::DefaultConfig }

    describe "caching behavior with same name and no settings" do
      let(:light) { system.light(name) }
      let(:name) { "foo" }

      it "returns cached instance on repeated calls" do
        expect(light).to equal(system.light(name))
      end
    end

    describe "isolation with different light names" do
      let(:light) { system.light(name) }
      let(:name) { "foo" }

      it "returns different instances for different names" do
        expect(light).not_to equal(system.light("bar"))
      end
    end

    describe "caching with identical settings" do
      let(:light) { system.light(name, cool_off_time: 30, threshold: 4) }
      let(:name) { "foo" }

      it "returns cached instance when settings match exactly" do
        expect(light).to equal(system.light(name, cool_off_time: 30, threshold: 4))
      end
    end

    describe "caching with settings in different order" do
      let(:light) { system.light(name, cool_off_time: 30, threshold: 4) }
      let(:name) { "foo" }

      it "returns cached instance regardless of parameter order" do
        expect(light).to equal(system.light(name, threshold: 4, cool_off_time: 30))
      end
    end

    describe "configuration conflict detection" do
      before do
        system.light("name", cool_off_time: 30, threshold: 4)
      end

      it "raises error when same name used with different settings" do
        expect do
          system.light("name", cool_off_time: 30, threshold: 5)
        end.to raise_error(Stoplight::Error::ConfigurationError)
      end
    end

    describe "different names with different settings" do
      let(:light) { system.light("bar", cool_off_time: 30, threshold: 4) }

      it "allows different configurations for different light names" do
        expect(light).not_to equal(system.light("foo", cool_off_time: 30, threshold: 5))
      end
    end

    describe "with normalized equivalent settings" do
      let!(:light) { system.light("bar", tracked_errors: RuntimeError) }

      it "returns same light when tracked_errors is normalized" do
        expect(light).to equal(system.light("bar", tracked_errors: [RuntimeError]))
      end
    end

    describe "with different traffic control strategies" do
      before { system.light("bar", traffic_control: :consecutive_errors) }

      it "raises error when same name uses different strategies" do
        expect do
          system.light("bar", traffic_control: :error_rate, threshold: 0.3)
        end.to raise_error(Stoplight::Error::ConfigurationError)
      end
    end

    describe "concurrent access" do
      let(:expected) { system.light("bar", cool_off_time: 30) }

      let(:lights) do
        100.times
          .map { Thread.new { system.light("bar", cool_off_time: 30) } }
          .each(&:join)
          .map(&:value)
      end

      it "creates only one light instance when called concurrently" do
        lights.each { |light| expect(light).to equal(expected) }
      end
    end

    describe "with partially overlapping settings" do
      before { system.light("bar", cool_off_time: 30) }

      it "raises error when adding different setting to same name" do
        expect do
          system.light("bar", cool_off_time: 30, threshold: 44)
        end.to raise_error(Stoplight::Error::ConfigurationError)
      end
    end

    describe "with a Redis-backed system", :redis do
      let(:system_config) do
        Stoplight::Wiring::DefaultConfig.with(
          name: "redis-test-system",
          data_store: Stoplight::DataStore::Redis.new(redis)
        )
      end

      it "allows creating multiple lights without raising" do
        system.light("stripe")
        expect { system.light("paypal") }.not_to raise_error
      end
    end

    describe "inheriting system configuration" do
      before do
        system.light("foo")
      end

      it "raises error as user-provided settings does not match exactly" do
        expect do
          system.light("foo", threshold: system_config.threshold)
        end.to raise_error(Stoplight::Error::ConfigurationError)
      end
    end

    describe "error messages" do
      before { system.light("bar", cool_off_time: 30) }

      it "includes both configs in error message" do
        expect do
          system.light("bar", cool_off_time: 30, threshold: 44)
        end.to raise_error(
          include(/Light `bar` already registered with different configuration/)
            .and(include(/system_spec\.rb:135/))
            .and(include(/system_spec\.rb:139/))
        )
      end
    end
  end
end
