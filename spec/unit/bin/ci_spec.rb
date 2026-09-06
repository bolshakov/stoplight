# frozen_string_literal: true

require_relative "../../../bin/ci"

RSpec.describe CI do
  let(:config) do
    {
      "latest_ruby" => "4.0",
      "rubies" => ["3.3", "3.4", "4.0"],
      "images" => ["redis:7.4", "redis:8.6", "valkey/valkey:9.1-alpine"],
      "latest_images" => ["redis:8.6", "valkey/valkey:9.1-alpine"]
    }
  end

  describe CI::Versions do
    subject(:versions) { described_class.new(config) }

    describe "#smoke" do
      it "pairs the latest Ruby with every latest image" do
        expect(versions.smoke).to eq(
          "include" => [
            {"ruby" => "4.0", "data-store-image" => "redis:8.6"},
            {"ruby" => "4.0", "data-store-image" => "valkey/valkey:9.1-alpine"}
          ]
        )
      end
    end

    describe "#extended" do
      it "covers every combination the smoke run did not already run" do
        expect(versions.extended).to eq(
          "include" => [
            {"ruby" => "3.3", "data-store-image" => "redis:7.4"},
            {"ruby" => "3.3", "data-store-image" => "redis:8.6"},
            {"ruby" => "3.3", "data-store-image" => "valkey/valkey:9.1-alpine"},
            {"ruby" => "3.4", "data-store-image" => "redis:7.4"},
            {"ruby" => "3.4", "data-store-image" => "redis:8.6"},
            {"ruby" => "3.4", "data-store-image" => "valkey/valkey:9.1-alpine"},
            {"ruby" => "4.0", "data-store-image" => "redis:7.4"}
          ]
        )
      end

      it "omits what smoke already covered" do
        expect(versions.extended["include"]).not_to include(*versions.smoke["include"])
      end

      it "together with smoke covers the whole matrix exactly once" do
        every_run = versions.smoke["include"] + versions.extended["include"]

        expect(every_run.uniq.size).to eq(config["rubies"].size * config["images"].size)
      end
    end

    describe "#features" do
      it "runs every light creation against every latest image on the Redis store" do
        redis = versions.features["include"].select { |entry| entry["data-store"] == "Redis" }

        expect(redis).to eq(
          [
            {"data-store" => "Redis", "light-creation" => "Stoplight()", "data-store-image" => "redis:8.6"},
            {"data-store" => "Redis", "light-creation" => "System#register", "data-store-image" => "redis:8.6"},
            {"data-store" => "Redis", "light-creation" => "Stoplight()", "data-store-image" => "valkey/valkey:9.1-alpine"},
            {"data-store" => "Redis", "light-creation" => "System#register", "data-store-image" => "valkey/valkey:9.1-alpine"}
          ]
        )
      end

      it "runs the Memory store once per light creation, since it ignores the image" do
        memory = versions.features["include"].select { |entry| entry["data-store"] == "Memory" }

        expect(memory).to eq(
          [
            {"data-store" => "Memory", "light-creation" => "Stoplight()", "data-store-image" => "redis:8.6"},
            {"data-store" => "Memory", "light-creation" => "System#register", "data-store-image" => "redis:8.6"}
          ]
        )
      end
    end

    describe "#latest_ruby" do
      it "returns the pinned Ruby" do
        expect(versions.latest_ruby).to eq("4.0")
      end
    end

    describe "validation" do
      it "accepts a consistent configuration" do
        expect { versions.validate! }.not_to raise_error
      end

      it "rejects a latest Ruby that is not among the tested Rubies" do
        config["latest_ruby"] = "4.1"

        expect { versions.validate! }
          .to raise_error(CI::Error, /latest_ruby 4\.1 is not in rubies/)
      end

      it "rejects a latest image that is not among the tested images" do
        config["latest_images"] = ["redis:9.0", "valkey/valkey:9.1-alpine"]

        expect { versions.validate! }
          .to raise_error(CI::Error, %r{latest_images entry redis:9\.0 is not in images})
      end

      it "reports every problem at once rather than stopping at the first" do
        config["latest_ruby"] = "4.1"
        config["latest_images"] = ["redis:9.0"]

        expect { versions.validate! }
          .to raise_error(CI::Error, /latest_ruby 4\.1.*latest_images entry redis:9\.0/m)
      end
    end
  end

  describe CI::Results do
    subject(:results) { described_class.new(needs) }

    context "when every job succeeded" do
      let(:needs) { {"spec" => {"result" => "success"}, "steep" => {"result" => "success"}} }

      it "reports no failures" do
        expect(results.failures).to be_empty
      end
    end

    context "when a job was skipped because its gate never opened" do
      let(:needs) { {"spec" => {"result" => "success"}, "spec-full" => {"result" => "skipped"}} }

      it "treats the skip as a failure" do
        expect(results.failures).to eq(["spec-full: skipped"])
      end
    end

    context "when jobs failed and were cancelled" do
      let(:needs) do
        {
          "steep" => {"result" => "failure"},
          "spec" => {"result" => "cancelled"},
          "rubocop" => {"result" => "success"}
        }
      end

      it "reports each non-success job" do
        expect(results.failures).to contain_exactly("steep: failure", "spec: cancelled")
      end
    end
  end
end
