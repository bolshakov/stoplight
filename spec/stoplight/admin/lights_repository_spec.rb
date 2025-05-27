# frozen_string_literal: true

RSpec.describe Stoplight::Admin::LightsRepository, :redis do
  subject(:repository) { described_class.new(data_store: data_store) }

  let(:data_store) { Stoplight::DataStore::Redis.new(redis) }
  let(:name) { "lights-repository" }
  let(:light) { Stoplight(name, data_store:) }

  describe "#all" do
    subject(:lights) { repository.all }

    context "when there are no lights" do
      it "returns empty array" do
        is_expected.to be_empty
      end
    end

    context "when there are lights" do
      before do
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
      Stoplight("red-light").with_data_store(data_store).lock("red")
      Stoplight("green-light").with_data_store(data_store).lock("green")
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
        begin
          (light.run { raise })
        rescue
          nil
        end
        begin
          (light.run { raise })
        rescue
          nil
        end
        begin
          (light.run { raise })
        rescue
          nil
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
      light.lock("red")
    end

    it "unlocks the light" do
      expect { unlock }
        .to change { light.state }
        .to("unlocked")
    end
  end
end
