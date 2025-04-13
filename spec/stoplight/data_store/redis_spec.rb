# frozen_string_literal: true

require "spec_helper"

RSpec.describe Stoplight::DataStore::Redis, :redis do
  let(:data_store) { described_class.new(redis) }
  let(:config) { Stoplight.config_provider.provide(name) }
  let(:name) { ("a".."z").to_a.shuffle.join }
  let(:failure) { Stoplight::Failure.new("class", "message", Time.new - 60) }
  let(:other) { Stoplight::Failure.new("class", "message 2", Time.new) }

  it_behaves_like "Stoplight::DataStore::Base"
  it_behaves_like "Stoplight::DataStore::Base#names"
  it_behaves_like "Stoplight::DataStore::Base#get_all"
  it_behaves_like "Stoplight::DataStore::Base#record_failure"
  it_behaves_like "Stoplight::DataStore::Base#clear_failures"
  it_behaves_like "Stoplight::DataStore::Base#get_state"
  it_behaves_like "Stoplight::DataStore::Base#set_state"
  it_behaves_like "Stoplight::DataStore::Base#clear_state"

  it_behaves_like "Stoplight::DataStore::Base#get_failures" do
    context "when JSON is invalid" do
      let(:config) { Stoplight.config_provider.provide(name, error_notifier: ->(_error) {}) }

      it "handles it without an error" do
        expect(failure).to receive(:to_json).and_return("invalid JSON")

        expect { data_store.record_failure(config, failure) }
          .to change { data_store.get_failures(config) }
          .to([have_attributes(error_class: "JSON::ParserError")])
      end
    end
  end

  it_behaves_like "Stoplight::DataStore::Base#with_deduplicated_notification"
end
