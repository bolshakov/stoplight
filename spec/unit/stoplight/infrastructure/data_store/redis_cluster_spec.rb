# frozen_string_literal: true

require "spec_helper"

RSpec.describe Stoplight::Infrastructure::DataStore::Redis do
  describe "cluster mode" do
    it "wraps light names in hash tags" do
      expect(described_class.key("metadata", "test-light", cluster_mode: true))
        .to eq("stoplight:v5:metadata:{test-light}")

      expect(described_class.key("metrics", "test-light", "success", 1234, cluster_mode: true))
        .to eq("stoplight:v5:metrics:{test-light}:success:1234")
    end

    it "generates bucket keys with hash tags" do
      keys = described_class.buckets_for_window(
        "test-light",
        metric: "failure",
        window_end: 1735578000,
        window_size: 7200,
        cluster_mode: true
      )

      expect(keys).to all(include("{test-light}"))
    end
  end
end
