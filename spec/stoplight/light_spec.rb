# coding: utf-8

require 'minitest/spec'
require 'stringio'
require 'stoplight'

describe Stoplight::Light do
  let(:light) { Stoplight::Light.new(name, &code) }
  let(:name) { ('a'..'z').to_a.shuffle.join }
  let(:code) { -> {} }

  it 'is a class' do
    Stoplight::Light.must_be_kind_of(Class)
  end

  describe '.default_data_store' do
    it 'is initially the default' do
      Stoplight::Light.default_data_store
        .must_equal(Stoplight::Default::DATA_STORE)
    end
  end

  describe '.default_data_store=' do
    before { @default_data_store = Stoplight::Light.default_data_store }
    after { Stoplight::Light.default_data_store = @default_data_store }

    it 'sets the data store' do
      data_store = Stoplight::DataStore::Memory.new
      Stoplight::Light.default_data_store = data_store
      Stoplight::Light.default_data_store.must_equal(data_store)
    end
  end

  describe '.default_error_notifier' do
    it 'is initially the default' do
      assert_equal(
        Stoplight::Light.default_error_notifier,
        Stoplight::Default::ERROR_NOTIFIER)
    end
  end

  describe '.default_error_notifier=' do
    before { @default_error_notifier = Stoplight::Light.default_error_notifier }
    after { Stoplight::Light.default_error_notifier = @default_error_notifier }

    it 'sets the error notifier' do
      default_error_notifier = -> _ {}
      Stoplight::Light.default_error_notifier = default_error_notifier
      assert_equal(
        Stoplight::Light.default_error_notifier, default_error_notifier)
    end
  end

  describe '.default_notifiers' do
    it 'is initially the default' do
      Stoplight::Light.default_notifiers
        .must_equal(Stoplight::Default::NOTIFIERS)
    end
  end

  describe '.default_notifiers=' do
    before { @default_notifiers = Stoplight::Light.default_notifiers }
    after { Stoplight::Light.default_notifiers = @default_notifiers }

    it 'sets the data store' do
      notifiers = []
      Stoplight::Light.default_notifiers = notifiers
      Stoplight::Light.default_notifiers.must_equal(notifiers)
    end
  end

  describe '#allowed_errors' do
    it 'is initially the default' do
      light.allowed_errors.must_equal(Stoplight::Default::ALLOWED_ERRORS)
    end
  end

  describe '#code' do
    it 'reads the code' do
      assert_equal(light.code, code)
    end
  end

  describe '#data_store' do
    it 'is initially the default' do
      light.data_store.must_equal(Stoplight::Light.default_data_store)
    end
  end

  describe '#error_notifier' do
    it 'it initially the default' do
      assert_equal(
        light.error_notifier, Stoplight::Light.default_error_notifier)
    end
  end

  describe '#fallback' do
    it 'is initially the default' do
      light.fallback.must_equal(Stoplight::Default::FALLBACK)
    end
  end

  describe '#name' do
    it 'reads the name' do
      light.name.must_equal(name)
    end
  end

  describe '#notifiers' do
    it 'is initially the default' do
      light.notifiers.must_equal(Stoplight::Light.default_notifiers)
    end
  end

  describe '#threshold' do
    it 'is initially the default' do
      light.threshold.must_equal(Stoplight::Default::THRESHOLD)
    end
  end

  describe '#timeout' do
    it 'is initially the default' do
      light.timeout.must_equal(Stoplight::Default::TIMEOUT)
    end
  end

  describe '#with_allowed_errors' do
    it 'adds the allowed errors to the default' do
      allowed_errors = [StandardError]
      light.with_allowed_errors(allowed_errors)
      light.allowed_errors
        .must_equal(Stoplight::Default::ALLOWED_ERRORS + allowed_errors)
    end
  end

  describe '#with_data_store' do
    it 'sets the data store' do
      data_store = Stoplight::DataStore::Memory.new
      light.with_data_store(data_store)
      light.data_store.must_equal(data_store)
    end
  end

  describe '#with_error_notifier' do
    it 'sets the error notifier' do
      error_notifier = -> _ {}
      light.with_error_notifier(&error_notifier)
      assert_equal(light.error_notifier, error_notifier)
    end
  end

  describe '#with_fallback' do
    it 'sets the fallback' do
      fallback = -> _ {}
      light.with_fallback(&fallback)
      assert_equal(light.fallback, fallback)
    end
  end

  describe '#with_notifiers' do
    it 'sets the notifiers' do
      notifiers = [Stoplight::Notifier::IO.new(StringIO.new)]
      light.with_notifiers(notifiers)
      light.notifiers.must_equal(notifiers)
    end
  end

  describe '#with_threshold' do
    it 'sets the threshold' do
      threshold = 12
      light.with_threshold(threshold)
      light.threshold.must_equal(threshold)
    end
  end

  describe '#with_timeout' do
    it 'sets the timeout' do
      timeout = 1.2
      light.with_timeout(timeout)
      light.timeout.must_equal(timeout)
    end
  end
end
