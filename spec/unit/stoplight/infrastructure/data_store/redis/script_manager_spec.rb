# frozen_string_literal: true

RSpec.describe Stoplight::Infrastructure::DataStore::Redis::ScriptManager, :redis do
  let(:script_manager) { described_class.new(redis:) }

  describe "#sha" do
    it "loads existing scripts lazily" do
      sha = script_manager.sha(:unbounded_metrics, :record_failure)
      expect(sha).not_to be_nil

      sha2 = script_manager.sha(:unbounded_metrics, :record_failure)

      expect(sha2).to eq(sha)
    end

    it "fails when unknown script name given" do
      expect do
        script_manager.sha(:unbounded_metrics, :unknown_script)
      end.to raise_error(Stoplight::Infrastructure::DataStore::Redis::ScriptManager::ScriptNotFound)
    end
  end
end
