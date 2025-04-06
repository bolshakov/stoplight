# frozen_string_literal: true

RSpec.shared_examples 'Stoplight::Light::Runnable#run' do
  let(:light) { super().with_notifiers(notifiers) }

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

  it { expect(light.config.data_store).to eq(data_store) }

  context 'when the light is green' do
    before { light.config.data_store.clear_failures(light) }

    it 'runs the code' do
      expect(run).to eql(code_result)
    end

    context 'with some failures' do
      before { light.config.data_store.record_failure(light, failure) }

      it 'clears the failures' do
        run
        expect(light.config.data_store.get_failures(light).size).to eql(0)
      end
    end

    context 'when the code is failing' do
      let(:code_result) { raise error }

      it 're-raises the error' do
        expect { run }.to raise_error(error.class)
      end

      it 'records the failure' do
        expect(light.config.data_store.get_failures(light).size).to eql(0)
        begin
          run
        rescue error.class
          nil
        end
        expect(light.config.data_store.get_failures(light).size).to eql(1)
      end

      context 'when error is not in the list of tracked errors' do
        let(:light) { super().with_tracked_errors(KeyError) }

        it 'does not record the failure' do
          expect do
            run
          rescue error.class
            nil
          end.not_to change {
            light.config.data_store.get_failures(light).size
          }.from(0)
        end
      end

      context 'when error is the list of tracked errors and in the list of skipped errors' do
        let(:light) { super().with_tracked_errors(error.class).with_skipped_errors(error.class) }

        it 'does not record the failure' do
          expect do
            run
          rescue error.class
            nil
          end.not_to change {
            light.config.data_store.get_failures(light).size
          }.from(0)
        end
      end

      context 'when error is in the list of tracked errors' do
        let(:light) { super().with_tracked_errors(KeyError, error.class) }

        it 'records the failure' do
          expect do
            run
          rescue error.class
            nil
          end.to change {
            light.config.data_store.get_failures(light).size
          }.by(1)
        end
      end

      context 'when error is in the list of skipped errors' do
        let(:light) { super().with_skipped_errors(KeyError, error.class) }

        it 'does not record the failure' do
          expect do
            run
          rescue error.class
            nil
          end.not_to change {
            light.config.data_store.get_failures(light).size
          }.from(0)
        end
      end

      context 'when error is not in the list of skipped errors' do
        let(:light) { super().with_skipped_errors(KeyError) }

        it 'records the failure' do
          expect do
            run
          rescue error.class
            nil
          end.to change {
            light.config.data_store.get_failures(light).size
          }.by(1)
        end
      end

      context 'when we did not send notifications yet' do
        it 'notifies when transitioning to red' do
          light.threshold.times do
            expect(io.string).to eql('')
            begin
              run
            rescue error.class
              nil
            end
          end
          expect(io.string).to_not eql('')
        end
      end

      context 'when we already sent notifications' do
        before do
          light.config.data_store.with_notification_lock(light, Stoplight::Color::GREEN,
                                                                Stoplight::Color::RED) do
end
        end

        it 'does not send new notifications' do
          light.threshold.times do
            expect(io.string).to eql('')
            begin
              run
            rescue error.class
              nil
            end
          end
          expect(io.string).to eql('')
        end
      end

      it 'notifies when transitioning to red' do
        light.threshold.times do
          expect(io.string).to eql('')
          begin
            run
          rescue error.class
            nil
          end
        end
        expect(io.string).to_not eql('')
      end

      context 'with a fallback' do
        it 'runs the fallback' do
          expect(run(fallback)).to eql(fallback_result)
        end

        it 'passes the error to the fallback' do
          expect(run(->(e) { e&.message || fallback_result })).to eql(error.message)
        end
      end
    end

    context 'when the data store is failing' do
      let(:error) { StandardError.new('something went wrong') }
      let(:light) do
        super().with_error_notifier do |e|
          @yielded_error = e
        end
      end

      before do
        allow(light.config.data_store).to receive(:clear_failures) { raise error }
      end

      it 'runs the code' do
        expect(run).to eql(code_result)
      end

      fit 'notifies about the error' do
        expect(@yielded_error).to be(nil)
        run
        expect(@yielded_error).to eql(error)
      end
    end
  end

  context 'when the light is yellow' do
    let(:failure) { Stoplight::Failure.new(error.class.name, error.message, Time.new - light.cool_off_time) }
    let(:failure2) { Stoplight::Failure.new(error.class.name, error.message, Time.new - light.cool_off_time - 10) }
    let(:light) { super().with_threshold(2) }

    before do
      light.config.data_store.record_failure(light, failure2)
      light.config.data_store.record_failure(light, failure)
    end

    it 'runs the code' do
      expect(run).to eql(code_result)
    end

    it 'notifies when transitioning to green' do
      expect { run }
        .to change(io, :string)
        .from(be_empty)
        .to(/Switching \w+ from red to green/)
    end
  end

  context 'when the light is red' do
    let(:other) do
      Stoplight::Failure.new(error.class.name, error.message, Time.new - light.cool_off_time)
    end
    let(:light) { super().with_threshold(2) }

    before do
      light.config.data_store.record_failure(light, other)
      light.config.data_store.record_failure(light, failure)
    end

    it 'raises an error' do
      expect { run }.to raise_error(Stoplight::Error::RedLight)
    end

    it 'uses the name as the error message' do
      expect do
        run
      end.to raise_error(Stoplight::Error::RedLight, light.name)
    end

    context 'with a fallback' do
      let(:fallback) { ->(error) { error || fallback_result } }

      it 'runs the fallback' do
        expect(run(fallback)).to eql(fallback_result)
      end
    end
  end
end
