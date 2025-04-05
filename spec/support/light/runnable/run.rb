# frozen_string_literal: true

RSpec.shared_examples 'Stoplight::Light::Runnable#run' do
  subject(:light) { Stoplight(name).build }

  let(:code) { -> { code_result } }
  let(:code_result) { random_string }
  let(:fallback) { ->(_) { fallback_result } }
  let(:fallback_result) { random_string }
  let(:name) { random_string }
  let(:notifiers) { [notifier] }
  let(:notifier) { Stoplight::Notifier::IO.new(io) }
  let(:io) { StringIO.new }

  before { light.with_notifiers(notifiers) }

  def run(fallback = nil)
    light.run(fallback, &code)
  end

  context 'when the light is green' do
    before { light.configuration.data_store.clear_failures(light) }

    it 'runs the code' do
      expect(run).to eql(code_result)
    end

    context 'with some failures' do
      before { light.configuration.data_store.record_failure(light, failure) }

      it 'clears the failures' do
        run
        expect(light.configuration.data_store.get_failures(light).size).to eql(0)
      end
    end

    context 'when the code is failing' do
      let(:code_result) { raise error }

      it 're-raises the error' do
        expect { run }.to raise_error(error.class)
      end

      it 'records the failure' do
        expect(light.configuration.data_store.get_failures(light).size).to eql(0)
        begin
          run
        rescue error.class
          nil
        end
        expect(light.configuration.data_store.get_failures(light).size).to eql(1)
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
          light.configuration.data_store.with_notification_lock(light, Stoplight::Color::GREEN,
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
      let(:error_notifier) { ->(_) {} }
      let(:error) { StandardError.new('something went wrong') }

      before do
        expect(data_store).to receive(:clear_failures) { raise error }

        light.with_error_notifier(&error_notifier)
      end

      it 'runs the code' do
        expect(run).to eql(code_result)
      end

      it 'notifies about the error' do
        has_notified = false
        light.with_error_notifier do |e|
          has_notified = true
          expect(e).to eq(error)
        end
        run
        expect(has_notified).to eql(true)
      end
    end
  end

  context 'when the light is yellow' do
    let(:failure) { Stoplight::Failure.new(error.class.name, error.message, Time.new - light.cool_off_time) }
    let(:failure2) { Stoplight::Failure.new(error.class.name, error.message, Time.new - light.cool_off_time - 10) }

    before do
      light.with_threshold(2)
      light.configuration.data_store.record_failure(light, failure2)
      light.configuration.data_store.record_failure(light, failure)
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

    before do
      light.with_threshold(2)
      light.configuration.data_store.record_failure(light, other)
      light.configuration.data_store.record_failure(light, failure)
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
