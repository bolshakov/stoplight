# coding: utf-8

shared_examples_for 'a data store' do
  let(:error) { error_class.new }
  let(:error_class) { Class.new(StandardError) }
  let(:name) { SecureRandom.hex }
  let(:state) { Stoplight::DataStore::STATES.to_a.sample }
  let(:threshold) { rand(10) }

  it 'is a DataStore::Base' do
    expect(data_store).to be_a(Stoplight::DataStore::Base)
  end

  describe '#names' do
    subject(:result) { data_store.names }

    it 'returns an array' do
      expect(result).to be_an(Array)
    end

    context 'with a name' do
      before do
        @data_store = Stoplight.data_store
        Stoplight.data_store(data_store)
        Stoplight::Light.new(name) {}.run
      end
      after { Stoplight.data_store(@data_store) }

      it 'includes the name' do
        expect(result).to include(name)
      end
    end
  end

  context 'attempts' do
    describe '#attempts' do
      subject(:result) { data_store.attempts(name) }

      it 'returns an integer' do
        expect(result).to be_an(Integer)
      end

      context 'with an attempt' do
        it 'includes the attempt' do
          attempts = data_store.attempts(name)
          data_store.record_attempt(name)
          expect(result).to be > attempts
        end
      end
    end

    describe '#clear_attempts' do
      subject(:result) { data_store.clear_attempts(name) }

      context 'with an attempt' do
        before { data_store.record_attempt(name) }

        it 'clears the attempts' do
          result
          expect(data_store.attempts(name)).to eql(0)
        end
      end
    end

    describe '#record_attempt' do
      subject(:result) { data_store.record_attempt(name) }

      it 'records the attempt' do
        attempts = data_store.attempts(name)
        result
        expect(data_store.attempts(name)).to eql(attempts + 1)
      end
    end
  end

  context 'failures' do
    describe '#clear_failures' do
      subject(:result) { data_store.clear_failures(name) }

      context 'with a failure' do
        before { data_store.record_failure(name, error) }

        it 'clears the failures' do
          result
          expect(data_store.failures(name)).to be_empty
        end
      end
    end

    describe '#failures' do
      subject(:result) { data_store.failures(name) }

      it 'returns an array' do
        expect(result).to be_an(Array)
      end

      context 'with a failure' do
        it 'includes the failure' do
          failures = data_store.failures(name)
          data_store.record_failure(name, error)
          expect(result.size).to be > failures.size
        end
      end
    end

    describe '#record_failure' do
      subject(:result) { data_store.record_failure(name, error) }

      it 'records the failure' do
        failures = data_store.failures(name)
        result
        expect(data_store.failures(name).size).to eql(failures.size + 1)
      end
    end
  end

  context 'state' do
    describe '#set_state' do
      subject(:result) { data_store.set_state(name, state) }

      it 'returns the state' do
        expect(result).to eql(state)
      end

      it 'sets the state' do
        result
        expect(data_store.state(name)).to eql(state)
      end
    end

    describe '#state' do
      subject(:result) { data_store.state(name) }

      it 'returns the default state' do
        expect(result).to eql(Stoplight::DataStore::STATE_UNLOCKED)
      end

      context 'with a state' do
        before { data_store.set_state(name, state) }

        it 'returns the state' do
          expect(result).to eql(state)
        end
      end
    end
  end

  context 'threshold' do
    describe '#set_threshold' do
      subject(:result) { data_store.set_threshold(name, threshold) }

      it 'returns the threshold' do
        expect(result).to eql(threshold)
      end

      it 'sets the threshold' do
        result
        expect(data_store.threshold(name)).to eql(threshold)
      end
    end

    describe '#threshold' do
      subject(:result) { data_store.threshold(name) }

      it 'returns nil' do
        expect(result).to eql(nil)
      end

      context 'with a threshold' do
        before { data_store.set_threshold(name, threshold) }

        it 'returns the threshold' do
          expect(result).to eql(threshold)
        end
      end
    end
  end
end
