# frozen_string_literal: true

RSpec.shared_examples "Stoplight::Light::Runnable#run" do
  let(:config) { super().with(notifiers: notifiers) }

  let(:code) { -> { code_result } }
  let(:code_result) { random_string }
  let(:fallback) { ->(_) { fallback_result } }
  let(:fallback_result) { random_string }
  let(:name) { random_string }
  let(:notifiers) { [notifier] }
  let(:notifier) { Stoplight::Notifier::IO.new(io) }
  let(:io) { StringIO.new }

  def run(fallback = nil)
    light.run(fallback, &code)
  end

  context "when the light is green" do
    before { data_store.clear_failures(config) }

    it "runs the code" do
      expect(run).to eql(code_result)
    end

    context "with some failures" do
      before { data_store.record_failure(config, failure) }

      it "clears the failures" do
        run
        expect(data_store.get_failures(config).size).to eql(0)
      end
    end

    context "when the code is failing" do
      let(:code_result) { raise error }

      it "re-raises the error" do
        expect { run }.to raise_error(error.class)
      end

      it "records the failure" do
        expect do
          run
        rescue error.class
          nil
        end.to change { data_store.get_failures(config).size }.from(0).to(1)
      end

      context "when error is not in the list of tracked errors" do
        let(:config) { super().with(tracked_errors: [KeyError]) }

        it "does not record the failure" do
          expect do
            run
          rescue error.class
            nil
          end.not_to change {
            config.data_store.get_failures(config).size
          }.from(0)
        end
      end

      context "when error is the list of tracked errors and in the list of skipped errors" do
        let(:config) do
          super().with(
            tracked_errors: [error.class],
            skipped_errors: [error.class]
          )
        end

        it "does not record the failure" do
          expect do
            run
          rescue error.class
            nil
          end.not_to change {
            config.data_store.get_failures(config).size
          }.from(0)
        end
      end

      context "when error is in the list of tracked errors" do
        let(:config) { super().with(tracked_errors: [KeyError, error.class]) }

        it "records the failure" do
          expect do
            run
          rescue error.class
            nil
          end.to change {
            config.data_store.get_failures(config).size
          }.by(1)
        end
      end

      context "when error is in the list of skipped errors" do
        let(:config) { super().with(skipped_errors: [KeyError, error.class]) }

        it "does not record the failure" do
          expect do
            run
          rescue error.class
            nil
          end.not_to change {
            light.config.data_store.get_failures(config).size
          }.from(0)
        end
      end

      context "when error is not in the list of skipped errors" do
        let(:config) { super().with(skipped_errors: [KeyError]) }

        it "records the failure" do
          expect do
            run
          rescue error.class
            nil
          end.to change {
            config.data_store.get_failures(config).size
          }.by(1)
        end
      end

      context "when we did not send notifications yet" do
        it "notifies when transitioning to red" do
          expect do
            config.threshold.times do
              expect(io.string).to eql("")
              begin
                run
              rescue error.class
                nil
              end
            end
          end.to change(io, :string).from("").to(
            include("Switching #{name} from green to red because #{error.class} #{error.message}")
          )
        end
      end

      context "when we already sent notifications" do
        before do
          data_store.with_deduplicated_notification(light, Stoplight::Color::GREEN, Stoplight::Color::RED) {}
        end

        it "does not send new notifications" do
          config.threshold.times do
            expect(io.string).to eql("")
            begin
              run
            rescue error.class
              nil
            end
          end
          expect(io.string).to eql("")
        end
      end

      it "notifies when transitioning to red" do
        config.threshold.times do
          expect(io.string).to eql("")
          begin
            run
          rescue error.class
            nil
          end
        end
        expect(io.string).to_not eql("")
      end

      context "with a fallback" do
        it "runs the fallback" do
          expect(run(fallback)).to eql(fallback_result)
        end

        it "passes the error to the fallback" do
          expect(run(->(e) { e&.message || fallback_result })).to eql(error.message)
        end
      end
    end
  end

  context "when the light is yellow" do
    let(:failure) { Stoplight::Failure.new(error.class.name, error.message, Time.new - config.cool_off_time) }
    let(:failure2) { Stoplight::Failure.new(error.class.name, error.message, Time.new - config.cool_off_time - 10) }
    let(:config) { super().with(threshold: 2) }

    before do
      data_store.record_failure(config, failure2)
      data_store.record_failure(config, failure)
    end

    it "runs the code" do
      expect(run).to eql(code_result)
    end

    it "notifies when transitioning to green" do
      expect { run }
        .to change(io, :string)
        .from(be_empty)
        .to(/Switching \w+ from red to green/)
    end
  end

  context "when the light is red" do
    let(:other) do
      Stoplight::Failure.new(error.class.name, error.message, Time.new - config.cool_off_time)
    end
    let(:config) { super().with(threshold: 2) }

    before do
      data_store.record_failure(config, other)
      data_store.record_failure(config, failure)
    end

    it "raises an error" do
      expect { run }.to raise_error(Stoplight::Error::RedLight)
    end

    it "uses the name as the error message" do
      expect do
        run
      end.to raise_error(Stoplight::Error::RedLight, light.name)
    end

    context "with a fallback" do
      let(:fallback) { ->(error) { error || fallback_result } }

      it "runs the fallback" do
        expect(run(fallback)).to eql(fallback_result)
      end
    end
  end
end
