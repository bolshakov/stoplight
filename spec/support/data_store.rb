# coding: utf-8
# rubocop:disable Metrics/LineLength

shared_examples_for 'a data store' do
  let(:name) { SecureRandom.hex }
  let(:failure) { Stoplight::Failure.new(error, time) }
  let(:error) { error_class.new }
  let(:error_class) { Class.new(StandardError) }
  let(:time) { Time.now }
  let(:state) { Stoplight::DataStore::STATES.to_a.sample }
  let(:threshold) { rand(100) }
  let(:timeout) { rand(100) }

  it { expect(data_store.names).to eql([]) }
  it { expect(data_store.clear_stale).to eql(nil) }
  it { expect(data_store.clear(name)).to eql(nil) }
  it { expect(data_store.sync(name)).to eql(nil) }
  it { expect(data_store.get_color(name)).to eql(Stoplight::DataStore::COLOR_GREEN) }
  it { expect(data_store.green?(name)).to eql(true) }
  it { expect(data_store.yellow?(name)).to eql(false) }
  it { expect(data_store.red?(name)).to eql(false) }
  it { expect(data_store.get_attempts(name)).to eql(Stoplight::DataStore::DEFAULT_ATTEMPTS) }
  it { expect(data_store.record_attempt(name)).to eql(1) }
  it { expect(data_store.clear_attempts(name)).to eql(nil) }
  it { expect(data_store.get_failures(name)).to eql(Stoplight::DataStore::DEFAULT_FAILURES) }
  it { expect(data_store.record_failure(name, failure)).to eql(failure) }
  it { expect(data_store.clear_failures(name)).to eql(nil) }
  it { expect(data_store.get_state(name)).to eql(Stoplight::DataStore::DEFAULT_STATE) }
  it { expect(data_store.set_state(name, state)).to eql(state) }
  it { expect(data_store.clear_state(name)).to eql(nil) }
  it { expect(data_store.get_threshold(name)).to eql(Stoplight::DataStore::DEFAULT_THRESHOLD) }
  it { expect(data_store.set_threshold(name, threshold)).to eql(threshold) }
  it { expect(data_store.clear_threshold(name)).to eql(nil) }
  it { expect(data_store.get_timeout(name)).to eql(Stoplight::DataStore::DEFAULT_TIMEOUT) }
  it { expect(data_store.set_timeout(name, timeout)).to eql(timeout) }
  it { expect(data_store.clear_timeout(name)).to eql(nil) }
end
