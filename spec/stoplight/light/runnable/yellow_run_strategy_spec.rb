# frozen_string_literal: true

require "spec_helper"

RSpec.describe Stoplight::Light::Runnable::YellowRunStrategy do
  subject(:strategy) { described_class.new(config) }

  let(:config) { Stoplight.config_provider.provide("foo", data_store:, notifiers: [notifier]) }
  let(:notifier) { instance_double(Stoplight::Notifier::Base) }

  shared_examples Stoplight::Light::Runnable::YellowRunStrategy do
    context "when code executes successfully" do
      subject(:result) { strategy.execute(nil, &code) }

      let(:code) { -> { "Success" } }

      context "when there are errors to clear" do
        let(:failures) { [Stoplight::Failure.from_error(StandardError.new)] }

        it "clears failures, notifies and return result" do
          expect(data_store).to receive(:clear_failures).with(config).and_return(failures)
          expect(notifier).to receive(:notify).with(config, Stoplight::Color::RED, Stoplight::Color::GREEN, nil)

          expect(result).to eq("Success")
        end
      end

      context "when there are not errors to clear" do
        let(:failures) { [] }

        it "clears failures, notifies and return result" do
          expect(data_store).to receive(:clear_failures).with(config).and_return([])
          expect(notifier).not_to receive(:notify)

          expect(result).to eq("Success")
        end
      end
    end

    context "when code fails" do
      subject(:result) { strategy.execute(fallback, &code) }

      let(:error) { StandardError.new("Test error") }
      let(:code) { -> { raise error } }
      let(:fallback) { nil }

      context "when error is tracked" do
        before do
          allow(config).to receive(:track_error?).with(error).and_return(true)
        end

        it "raises the error" do
          expect(notifier).not_to receive(:notify)

          expect do
            expect { result }.to raise_error(error)
          end.to change { data_store.get_failures(config).size }.by(1)
        end

        context "when fallback is provided" do
          let(:fallback) {
            ->(error) {
              @error = error
              "Fallback"
            }
          }

          it "records and raises the error" do
            expect(notifier).not_to receive(:notify)

            expect do
              expect(result).to eq("Fallback")
            end.to change { data_store.get_failures(config).size }.by(1)

            expect(@error).to eq(error)
          end
        end
      end

      context "when error is not tracked" do
        before do
          allow(config).to receive(:track_error?).with(error).and_return(false)
        end

        it "raises the error" do
          expect { result }.to raise_error(StandardError, "Test error")
        end
      end
    end
  end

  context "with memory data store" do
    let(:data_store) { Stoplight::DataStore::Memory.new }

    it_behaves_like Stoplight::Light::Runnable::YellowRunStrategy
  end

  context "with redis data store", :redis do
    let(:data_store) { Stoplight::DataStore::Redis.new(redis) }

    it_behaves_like Stoplight::Light::Runnable::YellowRunStrategy
  end
end
