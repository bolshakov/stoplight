# frozen_string_literal: true

RSpec.describe Stoplight::Admin::LightsRepository, :redis do
  subject(:repository) { described_class.new(registry:, storage:, system_config: system.config) }

  let(:system) { Stoplight.register_system(SecureRandom.uuid, data_store: data_store_config) }
  let(:storage) { system.__stoplight__storage }
  let(:registry) do
    Stoplight::Infrastructure::Redis::Storage::Registry.new(
      redis:,
      key_space: data_store_config.key_space.join(system.config.id),
      clock: Stoplight::Infrastructure::SystemClock.new,
      config_serializer: Stoplight::Infrastructure::ConfigSerializer
    )
  end
  let(:data_store_config) { Stoplight::DataStore::Redis.new(redis) }
  let(:name) { "lights-repository" }
  let(:id) { Stoplight::Domain::Id.for(name) }
  let(:light) { system.register(name) }

  describe "#all" do
    subject(:lights) { repository.all }

    context "when there are no lights" do
      it "returns empty array" do
        is_expected.to be_empty
      end
    end

    context "when there are lights" do
      before do
        light.run(->(_) {}) { raise "whoops" }
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
        light.run(->(_) {}) { raise "boom" }
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
    subject(:lock) { repository.lock(id) }

    context "when the light is green" do
      it "locks the light" do
        expect { lock }
          .to change(light, :state)
          .to("locked_green")
      end
    end

    context "when the light was never registered on this system" do
      subject(:lock) { repository.lock(id) }

      it "does not fail" do
        expect do
          lock
        end.not_to change(repository, :all)
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
          .to change(light, :state)
          .to("locked_red")
      end
    end
  end

  describe "#unlock" do
    subject(:unlock) { repository.unlock(id) }

    before do
      light.lock("red")
    end

    it "unlocks the light" do
      expect { unlock }
        .to change(light, :state)
        .to("unlocked")
    end
  end

  describe "#remove" do
    subject(:remove) { repository.remove(id) }

    before do
      light.run(->(_) {}) { raise "whoops" }
    end

    it "removes the light" do
      expect(repository.all).to contain_exactly(
        have_attributes(name:, failures: contain_exactly(have_attributes(error_class: "RuntimeError")))
      )

      remove

      expect(repository.all).to be_empty
    end
  end
end
