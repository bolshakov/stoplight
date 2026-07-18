# frozen_string_literal: true

RSpec.describe Stoplight::Admin::LightsRepository, :redis do
  subject(:repository) do
    described_class.new(registry:, storage:, system_config: system.system_config)
  end

  let(:system) { Stoplight.__stoplight__system(SecureRandom.uuid) }
  let(:storage) { system.__stoplight__storage }
  let(:registry) { instance_double(Stoplight::Infrastructure::Redis::Storage::Registry) }
  let(:data_store_config) { Stoplight::DataStore::Redis.new(redis) }
  let(:name) { "lights-repository" }
  let(:light) { system.register(name) }

  before do
    Stoplight.configure(trust_me_im_an_engineer: true) do |config|
      config.data_store = data_store_config
    end
  end

  describe "#all" do
    subject(:lights) { repository.all }

    context "when there are no lights" do
      before { allow(registry).to receive(:names).and_return([]) }

      it "returns empty array" do
        is_expected.to be_empty
      end
    end

    context "when there are lights" do
      before do
        allow(registry).to receive(:names).and_return([name])
        allow(registry).to receive(:config_for).and_return(nil)
        light.run { raise "whoops" }
      rescue
        nil
      end

      it "returns light" do
        is_expected.to contain_exactly(
          have_attributes(
            name: name,
            color: "green",
            state: "unlocked",
            failures: contain_exactly(
              have_attributes(
                error_class: "RuntimeError",
                error_message: "whoops"
              )
            )
          )
        )
      end
    end

    context "when the light was registered with an overridden window_size in another process" do
      let(:registry) { system.__stoplight__registry }
      let(:light) { system.register(name, window_size: 300) }

      before do
        light.run { raise "boom" }
      rescue
        nil
      end

      it "reads the failure from the light's real, windowed metrics" do
        is_expected.to contain_exactly(
          have_attributes(
            name: name,
            failure_count: 1,
            failures: contain_exactly(
              have_attributes(error_class: "RuntimeError", error_message: "boom")
            )
          )
        )
      end
    end
  end

  describe "#with_color" do
    before do
      allow(registry).to receive(:names).and_return(["red-light", "green-light"])
      allow(registry).to receive(:config_for).and_return(nil)
      system.register("red-light").lock("red")
      system.register("green-light").lock("green")
    end

    it "returns light with requested color" do
      expect(repository.with_color("green"))
        .to contain_exactly(have_attributes(color: "green", name: "green-light"))

      expect(repository.with_color("red"))
        .to contain_exactly(have_attributes(color: "red", name: "red-light"))

      expect(repository.with_color("red", "green")).to contain_exactly(
        have_attributes(color: "red", name: "red-light"),
        have_attributes(color: "green", name: "green-light")
      )

      expect(repository.with_color("yellow")).to be_empty
    end
  end

  describe "#lock" do
    subject(:lock) { repository.lock(light.name) }

    before { allow(registry).to receive(:config_for).and_return(nil) }

    context "when the light is green" do
      it "locks the light" do
        expect { lock }
          .to change { light.state }
          .to("locked_green")
      end
    end

    context "when the light was never registered on this system" do
      subject(:lock) { repository.lock("never-registered") }

      before { allow(registry).to receive(:names).and_return(["never-registered"]) }

      it "locks the light anyway" do
        lock

        expect(repository.all).to contain_exactly(
          have_attributes(name: "never-registered", state: "locked_green")
        )
      end
    end

    context "when the light is red" do
      before do
        until light.color == Stoplight::Color::RED
          light.run(->(_) {}) { raise }
        end
      end

      it "locks the light" do
        expect { lock }
          .to change { light.state }
          .to("locked_red")
      end
    end
  end

  describe "#unlock" do
    subject(:unlock) { repository.unlock(light.name) }

    before do
      allow(registry).to receive(:config_for).and_return(nil)
      light.lock("red")
    end

    it "unlocks the light" do
      expect { unlock }
        .to change { light.state }
        .to("unlocked")
    end
  end

  describe "#remove" do
    subject(:remove) { repository.remove(light.name) }

    before do
      allow(registry).to receive(:names).and_return([name])
      allow(registry).to receive(:config_for).and_return(nil)
      light.run { raise "whoops" }
    rescue
      nil
    end

    it "clears state and metrics so the light appears as fresh after removal" do
      expect(repository.all).to contain_exactly(
        have_attributes(name:, failures: contain_exactly(have_attributes(error_class: "RuntimeError")))
      )
      expect(registry).to receive(:unregister).with(light.name)

      remove

      expect(repository.all).to contain_exactly(
        have_attributes(name:, failures: be_empty, failure_count: 0)
      )
    end
  end
end
