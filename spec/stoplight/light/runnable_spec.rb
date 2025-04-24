# frozen_string_literal: true

require "spec_helper"
require "stringio"

RSpec.describe Stoplight::Light::Runnable, :redis do
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

  let(:config) { Stoplight.config_provider.provide(name, data_store: data_store) }
  let(:light) { Stoplight::Light.new(config) }

  context "with memory data store" do
    let(:data_store) { Stoplight::DataStore::Memory.new }

    it_behaves_like "Stoplight::Light::Runnable#state"
    it_behaves_like "Stoplight::Light::Runnable#color"
    it_behaves_like "Stoplight::Light::Runnable#run"
  end

  context "with redis data store", :redis do
    let(:data_store) { Stoplight::DataStore::Redis.new(redis) }

    it_behaves_like "Stoplight::Light::Runnable#state"
    it_behaves_like "Stoplight::Light::Runnable#color"
    it_behaves_like "Stoplight::Light::Runnable#run" do
      context "when the light is green" do
        before { data_store.clear_failures(config) }

        context "when the data store is failing" do
          let(:error) { StandardError.new("something went wrong") }
          let(:config) { super().with(error_notifier: ->(e) { @yielded_error = e }) }

          before do
            allow(data_store).to receive(:clear_failures) { raise error }
          end

          it "runs the code" do
            expect(run).to eql(code_result)
          end

          it "notifies about the error" do
            expect(@yielded_error).to be(nil)
            run
            expect(@yielded_error).to eql(error)
          end
        end
      end
    end
  end
end
