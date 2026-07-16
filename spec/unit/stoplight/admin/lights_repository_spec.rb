# frozen_string_literal: true

RSpec.describe Stoplight::Admin::LightsRepository, :redis do
  subject(:repository) { described_class.new(registry:, storage:, system_config: system.system_config) }

  let(:system) { Stoplight.__stoplight__system(SecureRandom.uuid) }
  let(:storage) { system.__stoplight__storage }
  let(:registry) { instance_double(Stoplight::Infrastructure::Redis::Storage::Registry) }
  let(:data_store_config) { Stoplight::DataStore::Redis.new(redis) }
  let(:name) { "lights-repository" }
  let(:light) { system.light(name) }

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
  end

  describe "#with_color" do
    before do
      allow(registry).to receive(:names).and_return(["red-light", "green-light"])
      system.light("red-light").lock("red")
      system.light("green-light").lock("green")
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

    context "when the light is green" do
      it "locks the light" do
        expect { lock }
          .to change { light.state }
          .to("locked_green")
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

    context "when the light was already registered elsewhere with overrides" do
      let(:overridden_name) { "overridden-light" }
      let(:overridden_light) { system.light(overridden_name, threshold: 10) }

      before { overridden_light }

      it "locks the light without raising ConfigurationError" do
        expect { repository.lock(overridden_name) }
          .to change { overridden_light.state }
          .to("locked_green")
      end
    end
  end

  describe "#unlock" do
    subject(:unlock) { repository.unlock(light.name) }

    before do
      light.lock("red")
    end

    it "unlocks the light" do
      expect { unlock }
        .to change { light.state }
        .to("unlocked")
    end

    context "when the light was already registered elsewhere with overrides" do
      let(:overridden_name) { "overridden-light" }
      let(:overridden_light) { system.light(overridden_name, threshold: 10) }

      before { overridden_light.lock("red") }

      it "unlocks the light without raising ConfigurationError" do
        expect { repository.unlock(overridden_name) }
          .to change { overridden_light.state }
          .to("unlocked")
      end
    end
  end

  describe "#remove" do
    subject(:remove) { repository.remove(light.name) }

    before do
      allow(registry).to receive(:names).and_return([name])
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
